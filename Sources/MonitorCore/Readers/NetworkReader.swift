import Foundation
import Darwin

public final class NetworkReader {
    private struct Raw { var bytesIn: UInt64; var bytesOut: UInt64; var isUp: Bool }

    private var previous: (counters: [String: Raw], time: TimeInterval)?
    private var sessionIn: UInt64 = 0
    private var sessionOut: UInt64 = 0

    public init() {}

    /// 64-bit per-interface counters from the routing socket's interface list.
    private func readCounters() -> [String: Raw]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return nil }

        var result: [String: Raw] = [:]
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let msgLen = Int(header.ifm_msglen)
                guard msgLen > 0 else { break }
                if header.ifm_type == UInt8(RTM_IFINFO2), offset + MemoryLayout<if_msghdr2>.size <= length {
                    let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    var nameBuf = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
                    if if_indextoname(UInt32(msg.ifm_index), &nameBuf) != nil {
                        let name = String(cString: nameBuf)
                        let up = (Int32(msg.ifm_flags) & IFF_UP) != 0 && (Int32(msg.ifm_flags) & IFF_RUNNING) != 0
                        result[name] = Raw(bytesIn: msg.ifm_data.ifi_ibytes, bytesOut: msg.ifm_data.ifi_obytes, isUp: up)
                    }
                }
                offset += msgLen
            }
        }
        return result
    }

    private func readAddresses() -> [String: (v4: String?, v6: String?)] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [:] }
        defer { freeifaddrs(list) }
        var out: [String: (v4: String?, v6: String?)] = [:]
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr else { continue }
            let family = Int32(addr.pointee.sa_family)
            guard family == AF_INET || family == AF_INET6 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let name = String(cString: ifa.ifa_name)
            var entry = out[name] ?? (nil, nil)
            let text = String(cString: host)
            if family == AF_INET { entry.v4 = text }
            else if entry.v6 == nil || entry.v6!.hasPrefix("fe80") { entry.v6 = text }
            out[name] = entry
        }
        return out
    }

    /// Returns nil on the first call (no previous counters) or on failure.
    public func read() -> NetworkSample? {
        let now = Sysctl.now
        guard let cur = readCounters() else { return nil }
        defer { previous = (cur, now) }
        guard let prev = previous else { return nil }
        let dt = now - prev.time

        let addresses = readAddresses()
        var totalIn: UInt64 = 0, totalOut: UInt64 = 0
        var interfaces: [NetworkInterfaceSample] = []

        for (name, raw) in cur {
            let old = prev.counters[name]
            let dIn = old.map { CounterMath.delta(prev: $0.bytesIn, cur: raw.bytesIn) } ?? 0
            let dOut = old.map { CounterMath.delta(prev: $0.bytesOut, cur: raw.bytesOut) } ?? 0
            if NetworkFilter.countsTowardTotal(name) {
                totalIn += dIn
                totalOut += dOut
            }
            if NetworkFilter.isPhysical(name), raw.isUp, addresses[name] != nil {
                interfaces.append(NetworkInterfaceSample(
                    name: name, ipv4: addresses[name]?.v4, ipv6: addresses[name]?.v6,
                    downBytesPerSecond: CounterMath.rate(delta: dIn, seconds: dt),
                    upBytesPerSecond: CounterMath.rate(delta: dOut, seconds: dt)))
            }
        }
        sessionIn += totalIn
        sessionOut += totalOut
        interfaces.sort { $0.name < $1.name }

        return NetworkSample(
            timestamp: now,
            downBytesPerSecond: CounterMath.rate(delta: totalIn, seconds: dt),
            upBytesPerSecond: CounterMath.rate(delta: totalOut, seconds: dt),
            sessionReceived: sessionIn, sessionSent: sessionOut, interfaces: interfaces)
    }
}
