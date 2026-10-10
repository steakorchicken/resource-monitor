import SwiftUI
import MonitorCore

/// Temporary Phase 2 readout so the raw numbers can be compared with Activity Monitor.
/// Replaced by the real detail views in Phase 3.
struct DebugReadout: View {
    let item: SidebarItem
    let store: MonitorStore

    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
    }

    private var text: String {
        switch item {
        case .cpu:
            guard let c = store.cpu else { return "Waiting for data…" }
            let info = store.systemInfo
            var lines = ["\(info.chipName) — \(info.performanceCores)P + \(info.efficiencyCores)E",
                         String(format: "Total %.1f%%  user %.1f%%  system %.1f%%  idle %.1f%%", c.total, c.user, c.system, c.idle),
                         String(format: "Load %.2f %.2f %.2f", c.loadAverage.one, c.loadAverage.five, c.loadAverage.fifteen),
                         "Uptime \(DurationFormatter.uptime(c.uptime))", ""]
            for (label, v) in zip(c.coreLabels, c.perCore) { lines.append(String(format: "%@  %5.1f%%", label.padding(toLength: 9, withPad: " ", startingAt: 0), v)) }
            return lines.joined(separator: "\n")
        case .memory:
            guard let m = store.memory else { return "Waiting for data…" }
            return [
                "Total       \(ByteFormatter.string(m.total))",
                "Used        \(ByteFormatter.string(m.used))",
                "  App       \(ByteFormatter.string(m.app))",
                "  Wired     \(ByteFormatter.string(m.wired))",
                "  Compressed \(ByteFormatter.string(m.compressed))",
                "Cached      \(ByteFormatter.string(m.cached))",
                "Free        \(ByteFormatter.string(m.free))",
                "Available   \(ByteFormatter.string(m.available))",
                "Swap        \(ByteFormatter.string(m.swapUsed)) of \(ByteFormatter.string(m.swapTotal))",
                "Pressure    \(m.pressure)",
            ].joined(separator: "\n")
        case .disk:
            guard let d = store.disk else { return "Waiting for data…" }
            var lines = ["Read  \(RateFormatter.string(bytesPerSecond: d.readBytesPerSecond))  \(Int(d.readOpsPerSecond)) IOPS",
                         "Write \(RateFormatter.string(bytesPerSecond: d.writeBytesPerSecond))  \(Int(d.writeOpsPerSecond)) IOPS", ""]
            for v in d.volumes {
                lines.append("\(v.name) (\(v.path)) \(ByteFormatter.string(v.used)) used of \(ByteFormatter.string(v.total)), \(ByteFormatter.string(v.available)) free, \(v.isInternal ? "internal" : "external")")
            }
            return lines.joined(separator: "\n")
        case .network:
            guard let n = store.network else { return "Waiting for data…" }
            var lines = ["Down \(RateFormatter.string(bytesPerSecond: n.downBytesPerSecond))   Up \(RateFormatter.string(bytesPerSecond: n.upBytesPerSecond))",
                         "Session received \(ByteFormatter.string(n.sessionReceived))   sent \(ByteFormatter.string(n.sessionSent))", ""]
            for i in n.interfaces {
                lines.append("\(i.name)  v4 \(i.ipv4 ?? "-")  v6 \(i.ipv6 ?? "-")  ↓\(RateFormatter.string(bytesPerSecond: i.downBytesPerSecond)) ↑\(RateFormatter.string(bytesPerSecond: i.upBytesPerSecond))")
            }
            return lines.joined(separator: "\n")
        default:
            return "Not built yet."
        }
    }
}
