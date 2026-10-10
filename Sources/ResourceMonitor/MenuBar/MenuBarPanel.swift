import SwiftUI
import MonitorCore

struct MenuBarPanel: View {
    let store: MonitorStore
    let settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var topProcesses: [ProcessInfoRow] {
        Array(store.processes.filter { ($0.cpuPercent ?? 0) > 0 }.sorted { ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }.prefix(3))
    }

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                miniCard("CPU", value: store.cpu.map { RateFormatter.percent($0.total) } ?? "—",
                         values: store.cpuHistory.elements, color: Theme.cpu, max: 100)
                miniCard("Memory", value: store.memory.map { String(format: "%.0f %%", Double($0.used) / Double($0.total) * 100) } ?? "—",
                         values: store.memoryUsedHistory.elements, color: Theme.memory,
                         max: Double(store.memory?.total ?? store.systemInfo.totalMemory))
                miniCard("Disk", value: store.disk.map { "R " + MenuBarLabel.compactRate($0.readBytesPerSecond).trimmingCharacters(in: .whitespaces) + " W " + MenuBarLabel.compactRate($0.writeBytesPerSecond).trimmingCharacters(in: .whitespaces) } ?? "—",
                         values: store.diskReadHistory.elements, color: Theme.disk,
                         max: niceMax(store.diskReadHistory.max() ?? 0, minimum: 1_000_000), small: true)
                miniCard("Network", value: store.network.map { "↓" + MenuBarLabel.compactRate($0.downBytesPerSecond).trimmingCharacters(in: .whitespaces) + " ↑" + MenuBarLabel.compactRate($0.upBytesPerSecond).trimmingCharacters(in: .whitespaces) } ?? "—",
                         values: store.netDownHistory.elements, color: Theme.networkDown,
                         max: niceMax(store.netDownHistory.max() ?? 0, minimum: 100_000), small: true)
            }

            extrasRow

            VStack(alignment: .leading, spacing: 6) {
                Text("Top processes").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textSecondary)
                if topProcesses.isEmpty {
                    Text("Collecting…").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }
                ForEach(topProcesses) { p in
                    HStack {
                        ProcessIconView(pid: p.pid)
                        Text(p.name).font(.system(size: 12)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1f%%", p.cpuPercent ?? 0)).font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            HStack(spacing: 8) {
                Button("Open Resource Monitor") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 320)
        .background(Theme.windowBackground)
        .preferredColorScheme(.dark)
        .onAppear { store.processViewAppeared() }
        .onDisappear { store.processViewDisappeared() }
    }

    private var extrasRow: some View {
        HStack(spacing: 14) {
            if let g = store.gpu { extra("GPU", String(format: "%.0f%%", g.deviceUtilization), Theme.gpu) }
            if let t = store.sensors?.cpuAverage { extra("Temp", String(format: "%.0f °C", t), Theme.sensors) }
            if let b = store.battery { extra("Battery", String(format: "%.0f%%", b.percent) + (b.state == .charging ? " ⚡︎" : ""), Theme.battery) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private func extra(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(Theme.textSecondary)
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.system(size: 12))
    }

    private func miniCard(_ title: String, value: String, values: [Double], color: Color, max: Double, small: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: small ? 13 : 20, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                .frame(height: 24, alignment: .leading)
            SparklineView(values: values, color: color, maxValue: max).frame(height: 30)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.cardBorder, lineWidth: 1))
    }
}
