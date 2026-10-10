import SwiftUI
import MonitorCore

struct DiskDetailView: View {
    let store: MonitorStore
    private let writeColor = Color(hex: 0x9BF0C9)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Disk", subtitle: store.disk?.volumes.first(where: { $0.path == "/" })?.name ?? "Storage", tint: Theme.disk)
                if let d = store.disk { content(d) } else {
                    Text("Waiting for data…").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func content(_ d: DiskSample) -> some View {
        let top = niceMax(max(store.diskReadHistory.max() ?? 0, store.diskWriteHistory.max() ?? 0), minimum: 1_000_000)
        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "Disk activity") {
                LiveChartView(series: [
                    ChartSeries(name: "Write", values: store.diskWriteHistory.elements, color: writeColor),
                    ChartSeries(name: "Read", values: store.diskReadHistory.elements, color: Theme.disk),
                ], yMax: top, yLabel: { RateFormatter.string(bytesPerSecond: $0) }, height: 200)
                HStack(spacing: 24) {
                    LegendItem(color: Theme.disk, label: "Read", value: RateFormatter.string(bytesPerSecond: d.readBytesPerSecond))
                    LegendItem(color: writeColor, label: "Write", value: RateFormatter.string(bytesPerSecond: d.writeBytesPerSecond))
                }
            }

            TileGrid {
                StatTile(label: "Read speed", value: RateFormatter.string(bytesPerSecond: d.readBytesPerSecond), tint: Theme.disk)
                StatTile(label: "Write speed", value: RateFormatter.string(bytesPerSecond: d.writeBytesPerSecond), tint: writeColor)
                StatTile(label: "Read IOPS", value: String(format: "%.0f", d.readOpsPerSecond))
                StatTile(label: "Write IOPS", value: String(format: "%.0f", d.writeOpsPerSecond))
            }

            ForEach(d.volumes) { v in
                SectionCard {
                    HStack {
                        Image(systemName: v.isRemovable ? "externaldrive" : "internaldrive").foregroundStyle(Theme.disk)
                        Text(v.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                        Text(v.isInternal ? "Internal" : "External")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.cardBorder, in: Capsule())
                        Spacer()
                        Text(String(format: "%.0f%% full", v.usedFraction * 100))
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
                    UsageBar(fraction: v.usedFraction, tint: Theme.disk, colorByLevel: true, height: 10)
                    Text("\(ByteFormatter.string(v.available)) free of \(ByteFormatter.string(v.total))")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}
