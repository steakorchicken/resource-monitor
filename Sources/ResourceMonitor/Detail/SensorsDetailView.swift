import SwiftUI
import MonitorCore

struct SensorsDetailView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Sensors", subtitle: "Read from the SMC · best effort", tint: Theme.sensors)
                if let s = store.sensors { content(s) } else {
                    Text("Sensor data not available on this Mac").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func tempColor(_ c: Double) -> Color { c >= 90 ? Theme.red : (c >= 75 ? Theme.yellow : Theme.sensors) }

    private func content(_ s: SensorSample) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if s.cpuAverage != nil {
                SectionCard(title: "CPU temperature (average)") {
                    LiveChartView(series: [ChartSeries(name: "CPU °C", values: store.cpuTempHistory.elements, color: Theme.sensors)],
                                  yMax: 110, yLabel: { "\(Int($0)) °C" }, height: 180)
                }
                TileGrid {
                    StatTile(label: "CPU average", value: s.cpuAverage.map { String(format: "%.1f °C", $0) } ?? "—", tint: Theme.sensors)
                    StatTile(label: "CPU hottest", value: s.cpuMax.map { String(format: "%.1f °C", $0) } ?? "—")
                    StatTile(label: "Sensors found", value: "\(s.temperatures.count)")
                }
            }

            if !s.fans.isEmpty {
                SectionCard(title: "Fans") {
                    ForEach(s.fans) { fan in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Fan \(fan.index + 1)").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(String(format: "%.0f RPM", fan.rpm)).font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.textPrimary)
                            }
                            let span = max(fan.maxRPM - fan.minRPM, 1)
                            UsageBar(fraction: (fan.rpm - fan.minRPM) / span, tint: Theme.gpu, height: 8)
                            Text(String(format: "min %.0f · max %.0f RPM", fan.minRPM, fan.maxRPM))
                                .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            ForEach(SensorGroup.allCases, id: \.self) { group in
                let items = s.temperatures.filter { $0.group == group }
                if !items.isEmpty {
                    SectionCard(title: group.rawValue) {
                        ForEach(items) { t in
                            HStack(spacing: 12) {
                                Text(t.name).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                                    .frame(width: 220, alignment: .leading).lineLimit(1)
                                UsageBar(fraction: t.celsius / 110, tint: tempColor(t.celsius), height: 6)
                                Text(String(format: "%.1f °C", t.celsius)).font(.system(size: 12).monospacedDigit())
                                    .foregroundStyle(Theme.textPrimary).frame(width: 64, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }
}
