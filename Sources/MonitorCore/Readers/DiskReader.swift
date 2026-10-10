import Foundation
import IOKit

public final class DiskReader {
    private struct Counters { var readBytes: UInt64 = 0, writeBytes: UInt64 = 0, readOps: UInt64 = 0, writeOps: UInt64 = 0 }

    private var previous: (counters: Counters, time: TimeInterval)?
    private var volumes: [VolumeInfo] = []
    private var volumesTime: TimeInterval = -.infinity

    public init() {}

    private func readCounters() -> Counters? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var sum = Counters()
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry); entry = IOIteratorNext(iterator) }
            guard let raw = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0),
                  let stats = raw.takeRetainedValue() as? [String: Any] else { continue }
            func value(_ key: String) -> UInt64 { (stats[key] as? NSNumber)?.uint64Value ?? 0 }
            sum.readBytes &+= value("Bytes (Read)")
            sum.writeBytes &+= value("Bytes (Write)")
            sum.readOps &+= value("Operations (Read)")
            sum.writeOps &+= value("Operations (Write)")
        }
        return sum
    }

    private func readVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey,
                                      .volumeAvailableCapacityForImportantUsageKey,
                                      .volumeIsInternalKey, .volumeIsRemovableKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  let total = v.volumeTotalCapacity, total > 0 else { return nil }
            return VolumeInfo(
                path: url.path, name: v.volumeName ?? url.lastPathComponent,
                total: UInt64(total),
                available: UInt64(max(0, v.volumeAvailableCapacityForImportantUsage ?? 0)),
                isInternal: v.volumeIsInternal ?? true, isRemovable: v.volumeIsRemovable ?? false)
        }
    }

    /// Returns nil on the first call (no previous counters) or on failure.
    public func read() -> DiskSample? {
        let now = Sysctl.now
        if now - volumesTime >= 10 {
            volumes = readVolumes()
            volumesTime = now
        }
        guard let cur = readCounters() else { return nil }
        defer { previous = (cur, now) }
        guard let prev = previous else { return nil }
        let dt = now - prev.time
        return DiskSample(
            timestamp: now,
            readBytesPerSecond: CounterMath.rate(delta: CounterMath.delta(prev: prev.counters.readBytes, cur: cur.readBytes), seconds: dt),
            writeBytesPerSecond: CounterMath.rate(delta: CounterMath.delta(prev: prev.counters.writeBytes, cur: cur.writeBytes), seconds: dt),
            readOpsPerSecond: CounterMath.rate(delta: CounterMath.delta(prev: prev.counters.readOps, cur: cur.readOps), seconds: dt),
            writeOpsPerSecond: CounterMath.rate(delta: CounterMath.delta(prev: prev.counters.writeOps, cur: cur.writeOps), seconds: dt),
            volumes: volumes)
    }
}
