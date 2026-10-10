import SwiftUI
import MonitorCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case gpu = "GPU"
    case sensors = "Sensors"
    case battery = "Battery"
    case processes = "Processes"
    case settings = "Settings"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .cpu: Theme.cpu
        case .memory: Theme.memory
        case .disk: Theme.disk
        case .network: Theme.networkDown
        case .gpu: Theme.gpu
        case .sensors: Theme.sensors
        case .battery: Theme.battery
        case .processes, .settings: Theme.textSecondary
        }
    }

}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let store: MonitorStore

    var body: some View {
        List(selection: $selection) {
            ForEach(store.availableSections) { item in
                resourceRow(item).tag(item)
                    .listRowSeparator(.hidden)
            }
            Divider().listRowSeparator(.hidden)
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(Theme.textSecondary)
                Text("Processes").foregroundStyle(Theme.textPrimary)
            }
            .tag(SidebarItem.processes)
            HStack(spacing: 8) {
                Image(systemName: "gearshape").foregroundStyle(Theme.textSecondary)
                Text("Settings").foregroundStyle(Theme.textPrimary)
            }
            .tag(SidebarItem.settings)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.windowBackground)
    }

    private func resourceRow(_ item: SidebarItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.rawValue).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Text(subtitle(item)).font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            spark(item).frame(height: 28)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func spark(_ item: SidebarItem) -> some View {
        switch item {
        case .cpu:
            SparklineView(values: store.cpuHistory.elements, color: item.tint, maxValue: 100)
        case .memory:
            SparklineView(values: store.memoryUsedHistory.elements, color: item.tint,
                          maxValue: Double(store.memory?.total ?? store.systemInfo.totalMemory))
        case .disk:
            let top = niceMax(max(store.diskReadHistory.max() ?? 0, store.diskWriteHistory.max() ?? 0), minimum: 1_000_000)
            ZStack {
                SparklineView(values: store.diskWriteHistory.elements, color: item.tint.opacity(0.5), maxValue: top)
                SparklineView(values: store.diskReadHistory.elements, color: item.tint, maxValue: top)
            }
        case .network:
            let top = niceMax(max(store.netDownHistory.max() ?? 0, store.netUpHistory.max() ?? 0), minimum: 100_000)
            ZStack {
                SparklineView(values: store.netUpHistory.elements, color: Theme.networkUp, maxValue: top)
                SparklineView(values: store.netDownHistory.elements, color: Theme.networkDown, maxValue: top)
            }
        case .gpu:
            SparklineView(values: store.gpuHistory.elements, color: item.tint, maxValue: 100)
        case .sensors:
            SparklineView(values: store.cpuTempHistory.elements, color: item.tint, maxValue: 110)
        case .battery:
            SparklineView(values: store.batteryHistory.elements, color: item.tint, maxValue: 100)
        case .processes, .settings:
            EmptyView()
        }
    }

    private func subtitle(_ item: SidebarItem) -> String {
        switch item {
        case .cpu:
            return store.cpu.map { RateFormatter.percent($0.total) } ?? "—"
        case .memory:
            guard let m = store.memory else { return "—" }
            return "\(ByteFormatter.memoryString(m.used)) / \(ByteFormatter.memoryString(m.total))"
        case .disk:
            guard let d = store.disk else { return "—" }
            return "R \(RateFormatter.string(bytesPerSecond: d.readBytesPerSecond))  ·  W \(RateFormatter.string(bytesPerSecond: d.writeBytesPerSecond))"
        case .network:
            guard let n = store.network else { return "—" }
            return "↓ \(RateFormatter.string(bytesPerSecond: n.downBytesPerSecond))  ↑ \(RateFormatter.string(bytesPerSecond: n.upBytesPerSecond))"
        case .gpu:
            return store.gpu.map { RateFormatter.percent($0.deviceUtilization) } ?? "—"
        case .sensors:
            return store.sensors?.cpuAverage.map { String(format: "CPU %.0f °C", $0) } ?? "—"
        case .battery:
            guard let b = store.battery else { return "—" }
            return String(format: "%.0f %% · ", b.percent) + (b.state == .charging ? "Charging" : (b.state == .charged ? "Charged" : "On battery"))
        case .processes, .settings:
            return ""
        }
    }
}
