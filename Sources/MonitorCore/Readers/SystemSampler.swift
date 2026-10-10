import Foundation

/// Owns all readers. Not thread-safe: call `sample()` from one place at a time.
public final class SystemSampler: @unchecked Sendable {
    private let cpu = CPUReader()
    private let memory = MemoryReader()
    private let disk = DiskReader()
    private let network = NetworkReader()
    private let processes = ProcessReader()

    public init() {
        _ = sample(includeProcesses: true)   // prime delta-based readers
    }

    public func sample(includeProcesses: Bool = false) -> Snapshot {
        Snapshot(cpu: cpu.read(), memory: memory.read(), disk: disk.read(), network: network.read(),
                 processes: includeProcesses ? processes.read() : nil)
    }
}
