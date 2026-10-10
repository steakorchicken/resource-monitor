import SwiftUI
import MonitorCore

/// Compact, fixed-width text for the menu bar so it doesn't jiggle as values change.
struct MenuBarLabel: View {
    let store: MonitorStore
    let settings: AppSettings

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .monospacedDigit()
    }

    private var text: String {
        var parts: [String] = []
        for metric in MenuBarMetric.allCases where settings.isShown(metric) {
            switch metric {
            case .cpu: parts.append("CPU " + pct(store.cpu?.total))
            case .memory:
                if let m = store.memory { parts.append("MEM " + pct(Double(m.used) / Double(m.total) * 100)) } else { parts.append("MEM  --%") }
            case .network:
                parts.append("↓" + Self.compactRate(store.network?.downBytesPerSecond) + " ↑" + Self.compactRate(store.network?.upBytesPerSecond))
            case .gpu: parts.append("GPU " + pct(store.gpu?.deviceUtilization))
            case .temperature:
                parts.append(store.sensors?.cpuAverage.map { String(format: "%3.0f°C", $0) } ?? " --°C")
            }
        }
        return parts.isEmpty ? "Monitor" : parts.joined(separator: " · ")
    }

    private func pct(_ v: Double?) -> String { v.map { String(format: "%3.0f%%", $0) } ?? " --%" }

    /// 4 characters wide: "  0B", "12K", "1.5M", " 20M"…
    static func compactRate(_ bytesPerSecond: Double?) -> String {
        guard let b = bytesPerSecond else { return " -- " }
        let units: [(Double, String)] = [(1e9, "G"), (1e6, "M"), (1e3, "K")]
        for (scale, suffix) in units where b >= scale {
            let v = b / scale
            return v < 10 ? String(format: "%.1f%@", v, suffix) : String(format: "%3.0f%@", v, suffix)
        }
        return String(format: "%3.0fB", b)
    }
}
