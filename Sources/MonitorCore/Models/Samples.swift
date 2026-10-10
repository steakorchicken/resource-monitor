import Foundation

public enum CoreKind: Sendable, Equatable {
    case efficiency, performance, unknown
}

public struct CPUSample: Sendable {
    public var timestamp: TimeInterval
    /// All values are percentages 0...100.
    public var total: Double
    public var user: Double
    public var system: Double
    public var idle: Double
    public var perCore: [Double]
    public var coreLabels: [String]
    public var coreKinds: [CoreKind]
    public var loadAverage: (one: Double, five: Double, fifteen: Double)
    public var uptime: TimeInterval
}

public enum MemoryPressure: Int, Sendable {
    case normal = 1, warning = 2, critical = 4

    init(level: Int32) {
        switch level {
        case 4...: self = .critical
        case 2...3: self = .warning
        default: self = .normal
        }
    }
}

public struct MemorySample: Sendable {
    public var timestamp: TimeInterval
    public var total: UInt64
    public var app: UInt64
    public var wired: UInt64
    public var compressed: UInt64
    public var cached: UInt64
    public var free: UInt64
    public var used: UInt64
    public var available: UInt64
    public var swapTotal: UInt64
    public var swapUsed: UInt64
    public var pressure: MemoryPressure
}

public struct VolumeInfo: Sendable, Identifiable {
    public var id: String { path }
    public var path: String
    public var name: String
    public var total: UInt64
    public var available: UInt64
    public var isInternal: Bool
    public var isRemovable: Bool
    public var used: UInt64 { total > available ? total - available : 0 }
    public var usedFraction: Double { total == 0 ? 0 : Double(used) / Double(total) }
}

public struct DiskSample: Sendable {
    public var timestamp: TimeInterval
    public var readBytesPerSecond: Double
    public var writeBytesPerSecond: Double
    public var readOpsPerSecond: Double
    public var writeOpsPerSecond: Double
    public var volumes: [VolumeInfo]
}

public struct NetworkInterfaceSample: Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var ipv4: String?
    public var ipv6: String?
    public var downBytesPerSecond: Double
    public var upBytesPerSecond: Double
}

public struct NetworkSample: Sendable {
    public var timestamp: TimeInterval
    public var downBytesPerSecond: Double
    public var upBytesPerSecond: Double
    public var sessionReceived: UInt64
    public var sessionSent: UInt64
    public var interfaces: [NetworkInterfaceSample]
}

public struct SystemInfo: Sendable {
    public var chipName: String
    public var totalMemory: UInt64
    public var logicalCores: Int
    public var performanceCores: Int
    public var efficiencyCores: Int
    public var osVersion: String
}

/// Everything sampled in one tick. Values are nil when a reader has no data yet or failed.
public struct Snapshot: Sendable {
    public var cpu: CPUSample?
    public var memory: MemorySample?
    public var disk: DiskSample?
    public var network: NetworkSample?
    public var processes: ProcessSnapshot?
}
