import Foundation
import IOKit
import IOKit.ps

public final class BatteryReader {
    public init() {}

    /// nil on Macs without a battery.
    public func read() -> BatterySample? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc["Type"] as? String) == "InternalBattery" else { continue }

            let current = (desc["Current Capacity"] as? NSNumber)?.doubleValue ?? 0
            let maxCap = max((desc["Max Capacity"] as? NSNumber)?.doubleValue ?? 100, 1)
            let charging = (desc["Is Charging"] as? Bool) ?? false
            let charged = (desc["Is Charged"] as? Bool) ?? false
            let source = (desc["Power Source State"] as? String) ?? "Battery Power"

            let minutesKey = charging ? "Time to Full Charge" : "Time to Empty"
            var remaining: TimeInterval?
            if let m = (desc[minutesKey] as? NSNumber)?.intValue, m >= 0 { remaining = Double(m) * 60 }

            var sample = BatterySample(
                timestamp: Sysctl.now, percent: current / maxCap * 100,
                state: charged ? .charged : (charging ? .charging : .discharging),
                powerSource: source, timeRemaining: remaining,
                cycleCount: nil, healthPercent: nil, temperatureCelsius: nil, watts: nil)
            addSmartBatteryDetails(to: &sample)
            return sample
        }
        return nil
    }

    private func addSmartBatteryDetails(to sample: inout BatterySample) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
        }
        sample.cycleCount = number("CycleCount")?.intValue
        // Newer macOS nests capacities in a "BatteryData" dictionary; older versions had them at the top level.
        let data = IORegistryEntryCreateCFProperty(service, "BatteryData" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any] ?? [:]
        func capacity(_ key: String) -> Double? { (data[key] as? NSNumber)?.doubleValue ?? number(key)?.doubleValue }
        let design = capacity("DesignCapacity") ?? 0
        let full = capacity("AppleRawMaxCapacity") ?? capacity("NominalChargeCapacity") ?? 0
        if design > 0, full > 0 { sample.healthPercent = min(full / design * 100, 100) }
        if let t = number("Temperature")?.doubleValue, t > 0 { sample.temperatureCelsius = t / 100 }
        if let v = number("Voltage")?.doubleValue, let a = number("Amperage") {
            // Amperage is a signed 64-bit value stored unsigned (negative while discharging).
            let milliamps = Double(Int64(bitPattern: a.uint64Value))
            sample.watts = abs(v / 1000 * milliamps / 1000)
        }
    }
}
