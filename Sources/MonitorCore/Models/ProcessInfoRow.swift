import Foundation

public struct ProcessInfoRow: Identifiable, Sendable, Hashable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    public var user: String?
    public var uid: UInt32?
    /// Percent of one core (can exceed 100 on multicore). nil when the process is unreadable.
    public var cpuPercent: Double?
    public var memoryBytes: UInt64?
    public var threads: Int?
    public var diskReadBytesPerSecond: Double?
    public var diskWriteBytesPerSecond: Double?

    public init(pid: Int32, name: String, user: String? = nil, uid: UInt32? = nil, cpuPercent: Double? = nil,
                memoryBytes: UInt64? = nil, threads: Int? = nil,
                diskReadBytesPerSecond: Double? = nil, diskWriteBytesPerSecond: Double? = nil) {
        self.pid = pid; self.name = name; self.user = user; self.uid = uid
        self.cpuPercent = cpuPercent; self.memoryBytes = memoryBytes; self.threads = threads
        self.diskReadBytesPerSecond = diskReadBytesPerSecond; self.diskWriteBytesPerSecond = diskWriteBytesPerSecond
    }
}

public struct ProcessSnapshot: Sendable {
    public var rows: [ProcessInfoRow]
    public var processCount: Int { rows.count }
    public var threadCount: Int
}

public enum ProcessColumn: Hashable, Sendable {
    case name, pid, user, cpu, memory, threads, diskRead, diskWrite
}

/// One concrete comparator for every process-table column. Missing values ("—") always sort last,
/// whichever direction is chosen.
public struct ProcessSortComparator: SortComparator {
    public var column: ProcessColumn
    public var order: SortOrder

    public init(_ column: ProcessColumn, order: SortOrder = .forward) {
        self.column = column
        self.order = order
    }

    public func compare(_ lhs: ProcessInfoRow, _ rhs: ProcessInfoRow) -> ComparisonResult {
        switch column {
        case .name: return required(lhs.name.localizedStandardCompare(rhs.name))
        case .pid: return required(Self.cmp(lhs.pid, rhs.pid))
        case .user: return optional(lhs.user, rhs.user)
        case .cpu: return optional(lhs.cpuPercent, rhs.cpuPercent)
        case .memory: return optional(lhs.memoryBytes, rhs.memoryBytes)
        case .threads: return optional(lhs.threads, rhs.threads)
        case .diskRead: return optional(lhs.diskReadBytesPerSecond, rhs.diskReadBytesPerSecond)
        case .diskWrite: return optional(lhs.diskWriteBytesPerSecond, rhs.diskWriteBytesPerSecond)
        }
    }

    private static func cmp<V: Comparable>(_ l: V, _ r: V) -> ComparisonResult {
        l < r ? .orderedAscending : (l > r ? .orderedDescending : .orderedSame)
    }

    private func required(_ result: ComparisonResult) -> ComparisonResult {
        guard order == .reverse else { return result }
        return result == .orderedAscending ? .orderedDescending : (result == .orderedDescending ? .orderedAscending : .orderedSame)
    }

    private func optional<V: Comparable>(_ l: V?, _ r: V?) -> ComparisonResult {
        switch (l, r) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (l?, r?): return required(Self.cmp(l, r))
        }
    }
}
