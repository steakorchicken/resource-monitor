import SwiftUI

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
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases.filter { $0 != .processes }) { item in
                row(item)
            }
            Divider().listRowSeparator(.hidden)
            row(.processes)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.windowBackground)
    }

    private func row(_ item: SidebarItem) -> some View {
        HStack(spacing: 8) {
            Circle().fill(item.tint).frame(width: 8, height: 8)
            Text(item.rawValue).foregroundStyle(Theme.textPrimary)
        }
        .tag(item)
    }
}
