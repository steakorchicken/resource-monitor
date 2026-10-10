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
        case .processes: Theme.textSecondary
        }
    }

    /// Rows shown so far; GPU, Sensors and Battery arrive in Phase 5.
    static let resources: [SidebarItem] = [.cpu, .memory, .disk, .network]
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let store: MonitorStore

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.resources) { item in
                resourceRow(item).tag(item)
                    .listRowSeparator(.hidden)
            }
            Divider().listRowSeparator(.hidden)
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(Theme.textSecondary)
                Text("Processes").foregroundStyle(Theme.textPrimary)
            }
            .tag(SidebarItem.processes)
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
        default:
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
        default:
            return ""
        }
    }
}
