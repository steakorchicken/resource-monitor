import Foundation

/// Owns all readers. Not thread-safe: call `sample()` from one place at a time.
public final class SystemSampler: @unchecked Sendable {
    private let cpu = CPUReader()
    private let memory = MemoryReader()
    private let disk = DiskReader()
    private let network = NetworkReader()
    private let processes = ProcessReader()
    private let gpu = GPUReader(fallbackName: SystemInfoReader.read().chipName)
    private let battery = BatteryReader()
    private let sensors = SensorReader()
    private var lastBattery: BatterySample?
    private var lastBatteryTime: TimeInterval = -.infinity

    public init() {
        _ = sample(includeProcesses: true)   // prime delta-based readers
    }

    public func sample(includeProcesses: Bool = false) -> Snapshot {
        var snapshot = Snapshot(cpu: cpu.read(), memory: memory.read(), disk: disk.read(), network: network.read(),
                 processes: includeProcesses ? processes.read() : nil,
                 gpu: gpu.read(), battery: nil, sensors: sensors.read())
        snapshot.battery = batterySample()
        // The battery has no temperature property on recent macOS; borrow the SMC battery sensor.
        if snapshot.battery?.temperatureCelsius == nil, var b = snapshot.battery,
           let t = snapshot.sensors?.temperatures.first(where: { $0.group == .battery }) {
            b.temperatureCelsius = t.celsius
            snapshot.battery = b
        }
        return snapshot
    }

    /// Battery data changes slowly, so it is re-read every 5 s.
    private func batterySample() -> BatterySample? {
        let now = Sysctl.now
        if now - lastBatteryTime >= 5 {
            lastBattery = battery.read()
            lastBatteryTime = now
        }
        return lastBattery
    }
}
