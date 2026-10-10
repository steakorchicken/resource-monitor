import Foundation
import Darwin

public final class CPUReader {
    private var previous: [CoreTicks]?
    private let perfCores: Int?
    private let effCores: Int?

    public init() {
        perfCores = Sysctl.value("hw.perflevel0.logicalcpu", as: Int32.self).map(Int.init)
        effCores = Sysctl.value("hw.perflevel1.logicalcpu", as: Int32.self).map(Int.init)
    }

    private func readTicks() -> [CoreTicks]? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }
        let stride = Int(CPU_STATE_MAX)
        return (0..<Int(count)).map { i in
            func tick(_ state: Int32) -> UInt32 { UInt32(bitPattern: info[i * stride + Int(state)]) }
            return CoreTicks(user: tick(CPU_STATE_USER), system: tick(CPU_STATE_SYSTEM),
                             idle: tick(CPU_STATE_IDLE), nice: tick(CPU_STATE_NICE))
        }
    }

    /// Returns nil on the first call (no previous counters) or on failure.
    public func read() -> CPUSample? {
        guard let cur = readTicks() else { return nil }
        defer { previous = cur }
        guard let prev = previous, prev.count == cur.count, !cur.isEmpty else { return nil }

        let usages = zip(prev, cur).map { CPUMath.usage(prev: $0, cur: $1) }
        let n = Double(usages.count)
        let user = usages.map(\.user).reduce(0, +) / n
        let system = usages.map(\.system).reduce(0, +) / n
        let idle = usages.map(\.idle).reduce(0, +) / n

        let (labels, kinds) = coreLayout(count: cur.count)

        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)

        var uptime: TimeInterval = 0
        if let boot = Sysctl.value("kern.boottime", as: timeval.self) {
            uptime = Date().timeIntervalSince1970 - (Double(boot.tv_sec) + Double(boot.tv_usec) / 1e6)
        }

        return CPUSample(
            timestamp: Sysctl.now,
            total: user + system, user: user, system: system, idle: idle,
            perCore: usages.map { $0.user + $0.system },
            coreLabels: labels, coreKinds: kinds,
            loadAverage: (load[0], load[1], load[2]), uptime: uptime)
    }

    /// On Apple Silicon the efficiency cores have the lowest indices.
    private func coreLayout(count: Int) -> ([String], [CoreKind]) {
        if let p = perfCores, let e = effCores, p + e == count {
            let kinds = (0..<count).map { $0 < e ? CoreKind.efficiency : .performance }
            let labels = (0..<count).map { $0 < e ? "E-core \($0 + 1)" : "P-core \($0 - e + 1)" }
            return (labels, kinds)
        }
        return ((0..<count).map { "Core \($0 + 1)" }, Array(repeating: .unknown, count: count))
    }
}
