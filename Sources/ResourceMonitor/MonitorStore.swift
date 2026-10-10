import Foundation
import Observation
import MonitorCore

@Observable
@MainActor
final class MonitorStore {
    static let historyCapacity = 60

    let systemInfo = SystemInfoReader.read()
    let settings: AppSettings

    init(settings: AppSettings? = nil) { self.settings = settings ?? AppSettings.shared }


    private(set) var cpu: CPUSample?
    private(set) var memory: MemorySample?
    private(set) var disk: DiskSample?
    private(set) var network: NetworkSample?
    private(set) var gpu: GPUSample?
    private(set) var battery: BatterySample?
    private(set) var sensors: SensorSample?
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
    private(set) var gpuHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var cpuTempHistory = RingBuffer<Double>(capacity: historyCapacity)
    private(set) var batteryHistory = RingBuffer<Double>(capacity: historyCapacity)

    /// Number of visible views that want fresh process data. Otherwise processes refresh only every 30 s.
    @ObservationIgnored private var processDemand = 0
    @ObservationIgnored private var lastProcessSample: TimeInterval = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let sampler = SystemSampler()

    /// Sidebar rows that have data on this Mac. Stored (not computed from the samples) so views reading it
    /// are only invalidated when a section actually appears or disappears, not on every tick.
    private(set) var availableSections: [SidebarItem] = [.cpu, .memory, .disk, .network]

    func start() {
        guard task == nil else { return }
        let sampler = self.sampler
        task = Task { [weak self] in
            while !Task.isCancelled {
                let delay = self?.settings.updateInterval ?? 1.0
                try? await Task.sleep(for: .seconds(delay))
                // Readers run off the main actor; one combined snapshot is published per tick.
                guard let store = self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                // Process data costs the most to gather and render: 2 s while a process view is up, 30 s otherwise.
                let wantProcesses = now - store.lastProcessSample >= (store.processDemand > 0 ? 2 : 30)
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

    /// Sampling pauses while the window is hidden or minimized (nothing is showing the data).
    /// Histories restart on resume so the charts never show a stale gap as live data.
    func setWindowVisible(_ visible: Bool) {
        if visible, task == nil {
            resetHistories()
            lastProcessSample = 0
            start()
        } else if !visible {
            stop()
        }
    }

    private func resetHistories() {
        cpuHistory.removeAll(); memoryUsedHistory.removeAll(); swapHistory.removeAll()
        diskReadHistory.removeAll(); diskWriteHistory.removeAll()
        netDownHistory.removeAll(); netUpHistory.removeAll()
        gpuHistory.removeAll(); cpuTempHistory.removeAll(); batteryHistory.removeAll()
        coreHistories = []
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
        if let g = s.gpu {
            gpu = g
            gpuHistory.append(g.deviceUtilization)
        }
        // @Observable invalidates on every assignment, even of an identical value. The sampler hands back
        // cached battery (5 s) and sensor (2 s) samples between refreshes, so only assign real changes.
        // Histories still append every tick to stay aligned with the other charts.
        if s.battery?.timestamp != battery?.timestamp || s.battery?.temperatureCelsius != battery?.temperatureCelsius {
            battery = s.battery
        }
        if let b = s.battery { batteryHistory.append(b.percent) }
        if s.sensors?.timestamp != sensors?.timestamp { sensors = s.sensors }
        if let avg = s.sensors?.cpuAverage { cpuTempHistory.append(avg) }
        if let p = s.processes {
            processes = p.rows
            ProcessIcons.prune(alive: Set(p.rows.map(\.pid)))
            processCount = p.processCount
            threadCount = p.threadCount
        }
        if let n = s.network {
            network = n
            netDownHistory.append(n.downBytesPerSecond)
            netUpHistory.append(n.upBytesPerSecond)
        }

        var sections: [SidebarItem] = [.cpu, .memory, .disk, .network]
        if gpu != nil { sections.append(.gpu) }
        if sensors != nil { sections.append(.sensors) }
        if battery != nil { sections.append(.battery) }
        if sections != availableSections { availableSections = sections }
    }
}
