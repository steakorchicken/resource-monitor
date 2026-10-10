import Foundation

/// Best-effort temperatures and fan speeds from the SMC. Returns nil if nothing usable was found.
public final class SensorReader {
    private struct Sensor { var key: String; var name: String; var group: SensorGroup }

    private var smc: SMC?
    private var sensors: [Sensor] = []
    private var fanCount = 0
    private var discovered = false

    public init() { smc = SMC() }

    static func group(forKey key: String) -> SensorGroup {
        switch key.prefix(2) {
        case "Tp", "Te", "Tc", "TC": return .cpu
        case "Tg", "TG": return .gpu
        case "TB", "Tb": return .battery
        default: return .other
        }
    }

    /// Enumerates the SMC once and remembers every temperature key that returns a plausible value.
    private func discover(_ smc: SMC) {
        discovered = true
        fanCount = Int(smc.readNumber("FNum") ?? 0)
        var counters: [SensorGroup: Int] = [:]
        for i in 0..<smc.keyCount() {
            guard let key = smc.key(at: i), key.hasPrefix("T"), key.utf8.count == 4,
                  let raw = smc.readRaw(key), raw.type == "flt ",
                  let value = SMC.decode(raw), (10...120).contains(value) else { continue }
            let group = Self.group(forKey: key)
            counters[group, default: 0] += 1
            sensors.append(Sensor(key: key, name: "\(group.rawValue) sensor \(counters[group]!) (\(key))", group: group))
        }
    }

    public func read() -> SensorSample? {
        guard let smc else { return nil }
        if !discovered { discover(smc) }

        var temps: [TemperatureReading] = []
        for s in sensors {
            if let v = smc.readNumber(s.key), (0...130).contains(v) {
                temps.append(TemperatureReading(key: s.key, name: s.name, group: s.group, celsius: v))
            }
        }
        var fans: [FanReading] = []
        for i in 0..<fanCount {
            if let rpm = smc.readNumber("F\(i)Ac") {
                fans.append(FanReading(index: i, rpm: rpm, minRPM: smc.readNumber("F\(i)Mn") ?? 0, maxRPM: smc.readNumber("F\(i)Mx") ?? 0))
            }
        }
        guard !temps.isEmpty || !fans.isEmpty else { return nil }
        return SensorSample(timestamp: Sysctl.now, temperatures: temps, fans: fans)
    }
}
