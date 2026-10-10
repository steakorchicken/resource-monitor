import SwiftUI
import MonitorCore

struct CPUDetailView: View {
    let store: MonitorStore
    private var _perCore = State(initialValue: false)   // `@State` macro is unavailable in the CLT toolchain
    private var perCore: Bool { _perCore.wrappedValue }

    init(store: MonitorStore) { self.store = store }

    var body: some View {
        let info = store.systemInfo
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "CPU", subtitle: info.chipName, tint: Theme.cpu)

                Picker("", selection: _perCore.projectedValue) {
                    Text("Overall").tag(false)
                    Text("Per core").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 220)

                if let c = store.cpu {
                    if perCore { perCoreGrid(c) } else { overall(c, info) }
                } else {
                    Text("Waiting for data…").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func overall(_ c: CPUSample, _ info: SystemInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SectionCard {
                    RingGauge(fraction: c.total / 100, valueText: String(format: "%.0f%%", c.total),
                              caption: "Utilization", tint: Theme.cpu, size: 150)
                }
                .frame(width: 210)
                SectionCard(title: "% Utilization") {
                    LiveChartView(series: [ChartSeries(name: "CPU", values: store.cpuHistory.elements, color: Theme.cpu)],
                                  yMax: 100, yLabel: { "\(Int($0))%" }, height: 170)
                }
            }

            SectionCard(title: "Where the time goes") {
                SegmentedBar(segments: [
                    .init(label: "User", value: c.user, color: Theme.cpu),
                    .init(label: "System", value: c.system, color: Theme.sensors),
                    .init(label: "Idle", value: c.idle, color: Theme.cardBorder),
                ])
                HStack(spacing: 24) {
                    LegendItem(color: Theme.cpu, label: "User", value: String(format: "%.1f%%", c.user))
                    LegendItem(color: Theme.sensors, label: "System", value: String(format: "%.1f%%", c.system))
                    LegendItem(color: Theme.cardBorder, label: "Idle", value: String(format: "%.1f%%", c.idle))
                }
            }

            TileGrid {
                StatTile(label: "Load average", value: String(format: "%.2f", c.loadAverage.one),
                         detail: String(format: "5m %.2f · 15m %.2f", c.loadAverage.five, c.loadAverage.fifteen))
                StatTile(label: "Cores", value: "\(info.logicalCores)",
                         detail: "\(info.performanceCores) performance · \(info.efficiencyCores) efficiency")
                StatTile(label: "Uptime", value: DurationFormatter.uptime(c.uptime))
            }
        }
    }

    private func perCoreGrid(_ c: CPUSample) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            ForEach(Array(c.perCore.enumerated()), id: \.offset) { i, value in
                SectionCard {
                    HStack {
                        Text(c.coreLabels[i]).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f%%", value))
                            .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    SparklineView(values: i < store.coreHistories.count ? store.coreHistories[i].elements : [],
                                  color: c.coreKinds[i] == .efficiency ? Theme.gpu : Theme.cpu, maxValue: 100)
                        .frame(height: 56)
                        .background(Theme.windowBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    UsageBar(fraction: value / 100, tint: c.coreKinds[i] == .efficiency ? Theme.gpu : Theme.cpu, height: 5)
                }
            }
        }
    }
}
