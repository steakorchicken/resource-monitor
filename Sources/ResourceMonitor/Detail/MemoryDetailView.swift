import SwiftUI
import MonitorCore

struct MemoryDetailView: View {
    let store: MonitorStore

    private let appColor = Theme.memory
    private let wiredColor = Color(hex: 0x7B4FD6)
    private let compressedColor = Color(hex: 0xD9C2FF)
    private let cachedColor = Color(hex: 0x5A4590)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Memory", subtitle: "\(ByteFormatter.memoryString(store.systemInfo.totalMemory)) unified memory", tint: Theme.memory)
                if let m = store.memory { content(m) } else {
                    Text("Waiting for data…").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func content(_ m: MemorySample) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SectionCard {
                    RingGauge(fraction: Double(m.used) / Double(m.total),
                              valueText: String(format: "%.0f%%", Double(m.used) / Double(m.total) * 100),
                              caption: "\(ByteFormatter.memoryString(m.used)) used", tint: Theme.memory, size: 150)
                }
                .frame(width: 210)
                SectionCard(title: "Memory usage") {
                    LiveChartView(series: [ChartSeries(name: "Used", values: store.memoryUsedHistory.elements, color: Theme.memory)],
                                  yMax: Double(m.total), yLabel: { ByteFormatter.memoryString(UInt64($0)) }, height: 170)
                }
            }

            SectionCard(title: "Memory composition") {
                SegmentedBar(segments: [
                    .init(label: "App", value: Double(m.app), color: appColor),
                    .init(label: "Wired", value: Double(m.wired), color: wiredColor),
                    .init(label: "Compressed", value: Double(m.compressed), color: compressedColor),
                    .init(label: "Cached", value: Double(m.cached), color: cachedColor),
                    .init(label: "Free", value: Double(m.free), color: Theme.cardBorder),
                ], height: 22)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 24)], spacing: 8) {
                    LegendItem(color: appColor, label: "App", value: ByteFormatter.memoryString(m.app))
                    LegendItem(color: wiredColor, label: "Wired", value: ByteFormatter.memoryString(m.wired))
                    LegendItem(color: compressedColor, label: "Compressed", value: ByteFormatter.memoryString(m.compressed))
                    LegendItem(color: cachedColor, label: "Cached files", value: ByteFormatter.memoryString(m.cached))
                    LegendItem(color: Theme.cardBorder, label: "Free", value: ByteFormatter.memoryString(m.free))
                }
            }

            HStack(alignment: .top, spacing: 12) {
                SectionCard(title: "Memory pressure") { PressureGauge(level: m.pressure.rawValue) }
                SectionCard(title: "Swap") {
                    UsageBar(fraction: m.swapTotal == 0 ? 0 : Double(m.swapUsed) / Double(m.swapTotal), tint: Theme.memory, colorByLevel: true)
                    Text("\(ByteFormatter.memoryString(m.swapUsed)) of \(ByteFormatter.memoryString(m.swapTotal))")
                        .font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.textPrimary)
                }
            }

            TileGrid {
                StatTile(label: "Used", value: ByteFormatter.memoryString(m.used))
                StatTile(label: "Available", value: ByteFormatter.memoryString(m.available))
                StatTile(label: "Total", value: ByteFormatter.memoryString(m.total))
            }
        }
    }
}
