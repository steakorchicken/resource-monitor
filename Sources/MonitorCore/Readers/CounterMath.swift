import Foundation

/// Pure helpers for turning raw counters into rates; kept separate so they are unit-testable.
public enum CounterMath {
    /// Delta of a monotonically increasing 64-bit counter. A decrease (counter reset) counts as 0.
    public static func delta(prev: UInt64, cur: UInt64) -> UInt64 {
        cur >= prev ? cur - prev : 0
    }

    /// Delta of a 32-bit counter that wraps around.
    public static func delta32(prev: UInt32, cur: UInt32) -> UInt32 {
        cur &- prev
    }

    public static func rate(delta: UInt64, seconds: TimeInterval) -> Double {
        seconds > 0 ? Double(delta) / seconds : 0
    }
}

public struct CoreTicks: Equatable, Sendable {
    public var user: UInt32, system: UInt32, idle: UInt32, nice: UInt32
    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
}

public enum CPUMath {
    /// Usage percentages between two tick snapshots. `user` includes nice time.
    public static func usage(prev: CoreTicks, cur: CoreTicks) -> (user: Double, system: Double, idle: Double) {
        let u = Double(CounterMath.delta32(prev: prev.user, cur: cur.user))
            + Double(CounterMath.delta32(prev: prev.nice, cur: cur.nice))
        let s = Double(CounterMath.delta32(prev: prev.system, cur: cur.system))
        let i = Double(CounterMath.delta32(prev: prev.idle, cur: cur.idle))
        let total = u + s + i
        guard total > 0 else { return (0, 0, 100) }
        return (u / total * 100, s / total * 100, i / total * 100)
    }
}

public struct MemoryPages: Sendable {
    public var internalPages: UInt64, purgeable: UInt64, external: UInt64
    public var wired: UInt64, compressor: UInt64
    public init(internalPages: UInt64, purgeable: UInt64, external: UInt64, wired: UInt64, compressor: UInt64) {
        self.internalPages = internalPages; self.purgeable = purgeable; self.external = external
        self.wired = wired; self.compressor = compressor
    }
}

public enum MemoryMath {
    /// Activity Monitor's breakdown: used = app + wired + compressed.
    public static func compose(pages: MemoryPages, pageSize: UInt64, total: UInt64)
        -> (app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, free: UInt64, used: UInt64, available: UInt64)
    {
        let app = (pages.internalPages > pages.purgeable ? pages.internalPages - pages.purgeable : 0) * pageSize
        let wired = pages.wired * pageSize
        let compressed = pages.compressor * pageSize
        let cached = (pages.external + pages.purgeable) * pageSize
        let used = app + wired + compressed
        let free = total > used + cached ? total - used - cached : 0
        let available = total > used ? total - used : 0
        return (app, wired, compressed, cached, free, used, available)
    }
}

public enum NetworkFilter {
    static let excludedPrefixes = ["lo", "utun", "awdl", "llw", "bridge", "anpi", "ap", "gif", "stf"]

    /// Whether an interface counts toward the total throughput.
    public static func countsTowardTotal(_ name: String) -> Bool {
        !excludedPrefixes.contains { name.hasPrefix($0) }
    }

    public static func isPhysical(_ name: String) -> Bool { name.hasPrefix("en") }
}

public enum ProcessMath {
    /// CPU percent from cumulative CPU nanoseconds and the wall-clock nanoseconds between samples.
    public static func cpuPercent(prevCPUNanos: Double, curCPUNanos: Double, wallNanos: Double) -> Double {
        guard wallNanos > 0, curCPUNanos >= prevCPUNanos else { return 0 }
        return (curCPUNanos - prevCPUNanos) / wallNanos * 100
    }
}
