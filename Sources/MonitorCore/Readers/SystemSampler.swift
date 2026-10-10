import Foundation

/// Owns all readers. Not thread-safe: call `sample()` from one place at a time.
public final class SystemSampler: @unchecked Sendable {
    private let cpu = CPUReader()
    private let memory = MemoryReader()
    private let disk = DiskReader()
    private let network = NetworkReader()

    public init() {
        _ = sample()   // prime delta-based readers
    }

    public func sample() -> Snapshot {
        Snapshot(cpu: cpu.read(), memory: memory.read(), disk: disk.read(), network: network.read())
    }
}
