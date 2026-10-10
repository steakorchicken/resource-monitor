import Foundation

/// Best-effort temperatures and fan speeds from the SMC. Returns nil if nothing usable was found.
public final class SensorReader {
    private struct Sensor { var key: String; var name: String; var group: SensorGroup; var info: SMC.KeyInfo }
    private struct Fan { var index: Int; var ac: SMC.KeyInfo?; var min: SMC.KeyInfo?; var max: SMC.KeyInfo? }

    private var smc: SMC?
    private var sensors: [Sensor] = []
    private var fans: [Fan] = []
    private var lastSample: SensorSample?
    private var lastTime: TimeInterval = -.infinity
    /// SMC reads are comparatively expensive and temperatures change slowly, so re-read every 2 s.
    private let minInterval: TimeInterval = 2
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
        let fanCount = Int(smc.readNumber("FNum") ?? 0)
        fans = (0..<fanCount).map { Fan(index: $0, ac: smc.keyInfo("F\($0)Ac"), min: smc.keyInfo("F\($0)Mn"), max: smc.keyInfo("F\($0)Mx")) }
        var counters: [SensorGroup: Int] = [:]
        for i in 0..<smc.keyCount() {
            guard let key = smc.key(at: i), key.hasPrefix("T"), key.utf8.count == 4,
                  let info = smc.keyInfo(key), info.type == "flt ",
                  let raw = smc.readRaw(key, info: info),
                  let value = SMC.decode(raw), (10...120).contains(value) else { continue }
            let group = Self.group(forKey: key)
            counters[group, default: 0] += 1
            sensors.append(Sensor(key: key, name: "\(group.rawValue) sensor \(counters[group]!) (\(key))", group: group, info: info))
        }
    }

    public func read() -> SensorSample? {
        guard let smc else { return nil }
        let now = Sysctl.now
        if now - lastTime < minInterval { return lastSample }
        if !discovered { discover(smc) }

        var temps: [TemperatureReading] = []
        for s in sensors {
            if let v = smc.readNumber(s.key, info: s.info), (0...130).contains(v) {
                temps.append(TemperatureReading(key: s.key, name: s.name, group: s.group, celsius: v))
            }
        }
        var fanReadings: [FanReading] = []
        for f in fans {
            if let rpm = smc.readNumber("F\(f.index)Ac", info: f.ac) {
                fanReadings.append(FanReading(index: f.index, rpm: rpm,
                                              minRPM: smc.readNumber("F\(f.index)Mn", info: f.min) ?? 0,
                                              maxRPM: smc.readNumber("F\(f.index)Mx", info: f.max) ?? 0))
            }
        }
        lastTime = now
        lastSample = (temps.isEmpty && fanReadings.isEmpty) ? nil : SensorSample(timestamp: now, temperatures: temps, fans: fanReadings)
        return lastSample
    }
}
