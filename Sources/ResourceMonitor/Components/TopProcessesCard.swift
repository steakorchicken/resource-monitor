import SwiftUI
import MonitorCore

struct TopProcessesCard: View {
    enum Metric { case cpu, memory }

    let store: MonitorStore
    let metric: Metric
    let tint: Color

    private var top: [ProcessInfoRow] {
        let rows = store.processes
        switch metric {
        case .cpu: return Array(rows.filter { ($0.cpuPercent ?? 0) > 0 }.sorted { ($0.cpuPercent ?? 0) > ($1.cpuPercent ?? 0) }.prefix(5))
        case .memory: return Array(rows.sorted { ($0.memoryBytes ?? 0) > ($1.memoryBytes ?? 0) }.prefix(5))
        }
    }

    private func value(_ r: ProcessInfoRow) -> Double {
        metric == .cpu ? (r.cpuPercent ?? 0) : Double(r.memoryBytes ?? 0)
    }

    private func label(_ r: ProcessInfoRow) -> String {
        metric == .cpu ? String(format: "%.1f%%", r.cpuPercent ?? 0) : ByteFormatter.memoryString(r.memoryBytes ?? 0)
    }

    var body: some View {
        let rows = top
        let maxValue = max(rows.map(value).max() ?? 1, metric == .cpu ? 100 : 1)
        SectionCard(title: metric == .cpu ? "Top processes by CPU" : "Top processes by memory") {
            if rows.isEmpty {
                Text("Collecting…").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
            ForEach(rows) { r in
                HStack(spacing: 10) {
                    ProcessIconView(pid: r.pid)
                    Text(r.name).font(.system(size: 13)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        .frame(width: 170, alignment: .leading)
                    UsageBar(fraction: value(r) / maxValue, tint: tint, height: 6)
                    Text(label(r)).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .onAppear { store.processViewAppeared() }
        .onDisappear { store.processViewDisappeared() }
    }
}
