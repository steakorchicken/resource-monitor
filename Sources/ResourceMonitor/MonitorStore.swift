import Foundation
import Observation
import MonitorCore

@Observable
@MainActor
final class MonitorStore {
    static let historyCapacity = 60

    let systemInfo = SystemInfoReader.read()

    /// Seconds between samples (0.5, 1 or 2). Takes effect on the next tick.
    var interval: Double = 1.0

    private(set) var cpu: CPUSample?
    private(set) var memory: MemorySample?
    private(set) var disk: DiskSample?
    private(set) var network: NetworkSample?
    private(set) var processes: [ProcessInfoRow] = []
    private(set) var processCount = 0
    private(set) var threadCount = 0

    private(set) var cpuHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var coreHistories: [RingBuffer<Double>] = []
    private(set) var memoryUsedHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var swapHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var diskReadHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var diskWriteHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var netDownHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var netUpHistory = RingBuffer<Double>(capacity: historyCapacity)

    /// Number of visible views that want fresh process data every tick. Otherwise processes refresh every 5 s.
    @ObservationIgnored private var processDemand = 0
    @ObservationIgnored private var lastProcessSample: TimeInterval = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let sampler = SystemSampler()

    func start() {
        guard task == nil else { return }
        let sampler = self.sampler
        task = Task { [weak self] in
            while !Task.isCancelled {
                let delay = self?.interval ?? 1.0
                try? await Task.sleep(for: .seconds(delay))
                // Readers run off the main actor; one combined snapshot is published per tick.
                guard let store = self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let wantProcesses = store.processDemand > 0 || now - store.lastProcessSample >= 5
                if wantProcesses { store.lastProcessSample = now }
                let snapshot = await Task.detached(priority: .utility) { sampler.sample(includeProcesses: wantProcesses) }.value
                guard let self, !Task.isCancelled else { return }
                self.apply(snapshot)
            }
        }
    }

    func processViewAppeared() { processDemand += 1 }
    func processViewDisappeared() { processDemand = max(0, processDemand - 1) }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func apply(_ s: Snapshot) {
        if let cpu = s.cpu {
            self.cpu = cpu
            cpuHistory.append(cpu.total)
            if coreHistories.count != cpu.perCore.count {
                coreHistories = Array(repeating: RingBuffer(capacity: Self.historyCapacity), count: cpu.perCore.count)
            }
            for (i, v) in cpu.perCore.enumerated() { coreHistories[i].append(v) }
        }
        if let m = s.memory {
            memory = m
            memoryUsedHistory.append(Double(m.used))
            swapHistory.append(Double(m.swapUsed))
        }
        if let d = s.disk {
            disk = d
            diskReadHistory.append(d.readBytesPerSecond)
            diskWriteHistory.append(d.writeBytesPerSecond)
        }
        if let p = s.processes {
            processes = p.rows
            processCount = p.processCount
            threadCount = p.threadCount
        }
        if let n = s.network {
            network = n
            netDownHistory.append(n.downBytesPerSecond)
            netUpHistory.append(n.upBytesPerSecond)
        }
    }
}
