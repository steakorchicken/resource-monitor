import SwiftUI
import MonitorCore

struct BatteryDetailView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Battery", subtitle: store.battery?.powerSource ?? "", tint: Theme.battery)
                if let b = store.battery { content(b) } else {
                    Text("No battery in this Mac").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func stateText(_ b: BatterySample) -> String {
        switch b.state {
        case .charging: "Charging"
        case .charged: "Charged"
        case .discharging: "On battery"
        }
    }

    private func color(_ b: BatterySample) -> Color {
        b.state == .discharging && b.percent <= 15 ? Theme.red : (b.state == .discharging && b.percent <= 30 ? Theme.yellow : Theme.battery)
    }

    private func content(_ b: BatterySample) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                SectionCard {
                    RingGauge(fraction: b.percent / 100, valueText: String(format: "%.0f%%", b.percent),
                              caption: stateText(b), tint: color(b), size: 170)
                }
                .frame(width: 230)
                SectionCard(title: "Charge level") {
                    LiveChartView(series: [ChartSeries(name: "Battery", values: store.batteryHistory.elements, color: color(b))],
                                  yMax: 100, yLabel: { "\(Int($0))%" }, height: 190)
                }
            }

            TileGrid {
                StatTile(label: b.state == .charging ? "Time to full" : "Time remaining",
                         value: b.state == .charged ? "—" : (b.timeRemaining.map { DurationFormatter.short($0) } ?? "Calculating…"),
                         detail: stateText(b))
                StatTile(label: b.state == .charging ? "Charging power" : "Power draw",
                         value: b.watts.map { String(format: "%.1f W", $0) } ?? "—")
                StatTile(label: "Cycle count", value: b.cycleCount.map(String.init) ?? "—")
                StatTile(label: "Temperature", value: b.temperatureCelsius.map { String(format: "%.1f °C", $0) } ?? "—")
                StatTile(label: "Power source", value: b.powerSource == "AC Power" ? "AC adapter" : "Battery")
            }

            if let h = b.healthPercent {
                SectionCard(title: "Battery health") {
                    UsageBar(fraction: h / 100, tint: Theme.battery, height: 10)
                    Text(String(format: "%.0f%% of original capacity", h))
                        .font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }
}
