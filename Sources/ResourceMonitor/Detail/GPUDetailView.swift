import SwiftUI
import MonitorCore

struct GPUDetailView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "GPU", subtitle: store.gpu?.model ?? "GPU", tint: Theme.gpu)
                if let g = store.gpu { content(g) } else {
                    Text("GPU data not available on this Mac").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func content(_ g: GPUSample) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SectionCard {
                    RingGauge(fraction: g.deviceUtilization / 100, valueText: String(format: "%.0f%%", g.deviceUtilization),
                              caption: "Utilization", tint: Theme.gpu, size: 150)
                }
                .frame(width: 210)
                SectionCard(title: "% GPU utilization") {
                    LiveChartView(series: [ChartSeries(name: "GPU", values: store.gpuHistory.elements, color: Theme.gpu)],
                                  yMax: 100, yLabel: { "\(Int($0))%" }, height: 170)
                }
            }

            SectionCard(title: "Engines") {
                engine("Device", g.deviceUtilization)
                engine("Renderer", g.rendererUtilization)
                engine("Tiler", g.tilerUtilization)
            }

            TileGrid {
                StatTile(label: "Device", value: RateFormatter.percent(g.deviceUtilization), tint: Theme.gpu)
                StatTile(label: "Renderer", value: RateFormatter.percent(g.rendererUtilization))
                StatTile(label: "Tiler", value: RateFormatter.percent(g.tilerUtilization))
                StatTile(label: "GPU memory in use", value: ByteFormatter.memoryString(g.memoryInUse), detail: "shared with system RAM")
            }
        }
    }

    private func engine(_ name: String, _ value: Double) -> some View {
        HStack(spacing: 12) {
            Text(name).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(width: 80, alignment: .leading)
            UsageBar(fraction: value / 100, tint: Theme.gpu, height: 8)
            Text(String(format: "%.0f%%", value)).font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Theme.textPrimary).frame(width: 44, alignment: .trailing)
        }
    }
}
