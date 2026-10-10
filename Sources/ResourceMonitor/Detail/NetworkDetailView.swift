import SwiftUI
import MonitorCore

struct NetworkDetailView: View {
    let store: MonitorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Network", subtitle: store.network?.interfaces.first?.name ?? "No active interface", tint: Theme.networkDown)
                if let n = store.network { content(n) } else {
                    Text("Waiting for data…").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }

    private func content(_ n: NetworkSample) -> some View {
        let top = niceMax(max(store.netDownHistory.max() ?? 0, store.netUpHistory.max() ?? 0), minimum: 100_000)
        return VStack(alignment: .leading, spacing: 16) {
            SectionCard(title: "Throughput") {
                LiveChartView(series: [
                    ChartSeries(name: "Upload", values: store.netUpHistory.elements, color: Theme.networkUp),
                    ChartSeries(name: "Download", values: store.netDownHistory.elements, color: Theme.networkDown),
                ], yMax: top, yLabel: { RateFormatter.string(bytesPerSecond: $0) }, height: 200)
                HStack(spacing: 24) {
                    LegendItem(color: Theme.networkDown, label: "Download", value: RateFormatter.string(bytesPerSecond: n.downBytesPerSecond))
                    LegendItem(color: Theme.networkUp, label: "Upload", value: RateFormatter.string(bytesPerSecond: n.upBytesPerSecond))
                }
            }

            TileGrid {
                StatTile(label: "Download", value: RateFormatter.string(bytesPerSecond: n.downBytesPerSecond), tint: Theme.networkDown)
                StatTile(label: "Upload", value: RateFormatter.string(bytesPerSecond: n.upBytesPerSecond), tint: Theme.networkUp)
                StatTile(label: "Received this session", value: ByteFormatter.string(n.sessionReceived))
                StatTile(label: "Sent this session", value: ByteFormatter.string(n.sessionSent))
            }

            if n.interfaces.isEmpty {
                SectionCard {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash").foregroundStyle(Theme.textSecondary)
                        Text("No active network interface. Connect to Wi-Fi or Ethernet to see activity.")
                            .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            ForEach(n.interfaces) { i in
                SectionCard {
                    HStack {
                        Image(systemName: "network").foregroundStyle(Theme.networkDown)
                        Text(i.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("↓ \(RateFormatter.string(bytesPerSecond: i.downBytesPerSecond))   ↑ \(RateFormatter.string(bytesPerSecond: i.upBytesPerSecond))")
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPv4  \(i.ipv4 ?? "—")")
                        Text("IPv6  \(i.ipv6 ?? "—")")
                    }
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.textSecondary)
                    .textSelection(.enabled)
                }
            }
        }
    }
}
