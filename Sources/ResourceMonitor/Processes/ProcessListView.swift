import SwiftUI
import MonitorCore

/// View-only process table. There is intentionally no kill/quit action anywhere.
struct ProcessListView: View {
    let store: MonitorStore

    // `@State` macro is unavailable in the CLT toolchain, so State is used directly.
    private var _sortOrder = State(initialValue: [ProcessSortComparator(.cpu, order: .reverse)])
    private var _search = State(initialValue: "")
    private var _mineOnly: State<Bool>
    private var _selection = State(initialValue: Set<Int32>())

    init(store: MonitorStore) {
        self.store = store
        _mineOnly = State(initialValue: store.settings.processesMineOnly)
    }

    private var rows: [ProcessInfoRow] {
        let me = getuid()
        let query = _search.wrappedValue.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = store.processes.filter { row in
            if _mineOnly.wrappedValue, row.uid != me { return false }
            if query.isEmpty { return true }
            return row.name.lowercased().contains(query) || String(row.pid).contains(query)
        }
        return filtered.sorted(using: _sortOrder.wrappedValue)
    }

    var body: some View {
        let shown = rows
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                DetailHeader(title: "Processes", subtitle: "", tint: Theme.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                    TextField("Search name or PID", text: _search.projectedValue)
                        .textFieldStyle(.plain).foregroundStyle(Theme.textPrimary).frame(width: 180)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder))
                Picker("", selection: _mineOnly.projectedValue) {
                    Text("My processes").tag(true)
                    Text("All processes").tag(false)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 230)
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 12)

            Table(shown, selection: _selection.projectedValue, sortOrder: _sortOrder.projectedValue) {
                TableColumn("Name", sortUsing: ProcessSortComparator(.name)) { row in
                    HStack(spacing: 8) {
                        ProcessIconView(pid: row.pid)
                        Text(row.name).lineLimit(1)
                    }
                }
                .width(min: 160, ideal: 240)
                TableColumn("PID", sortUsing: ProcessSortComparator(.pid)) { row in
                    Text(String(row.pid)).monospacedDigit().foregroundStyle(Theme.textSecondary)
                }
                .width(min: 50, ideal: 64)
                TableColumn("User", sortUsing: ProcessSortComparator(.user)) { row in
                    Text(row.user ?? "—").foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                .width(min: 70, ideal: 100)
                TableColumn("CPU %", sortUsing: ProcessSortComparator(.cpu)) { row in
                    Text(row.cpuPercent.map { String(format: "%.1f", $0) } ?? "—").monospacedDigit()
                        .foregroundStyle((row.cpuPercent ?? 0) > 50 ? Theme.cpu : Theme.textPrimary)
                }
                .width(min: 60, ideal: 70)
                TableColumn("Memory", sortUsing: ProcessSortComparator(.memory)) { row in
                    Text(row.memoryBytes.map { ByteFormatter.memoryString($0) } ?? "—").monospacedDigit()
                }
                .width(min: 70, ideal: 90)
                TableColumn("Threads", sortUsing: ProcessSortComparator(.threads)) { row in
                    Text(row.threads.map(String.init) ?? "—").monospacedDigit()
                }
                .width(min: 55, ideal: 65)
                TableColumn("Disk read/s", sortUsing: ProcessSortComparator(.diskRead)) { row in
                    Text(rate(row.diskReadBytesPerSecond)).monospacedDigit()
                }
                .width(min: 70, ideal: 85)
                TableColumn("Disk write/s", sortUsing: ProcessSortComparator(.diskWrite)) { row in
                    Text(rate(row.diskWriteBytesPerSecond)).monospacedDigit()
                }
                .width(min: 70, ideal: 85)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.textPrimary)

            HStack {
                Text("\(shown.count) shown · \(store.processCount) processes · \(store.threadCount) threads")
                    .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 24).padding(.vertical, 10)
            .background(Theme.cardBackground)
        }
        .background(Theme.windowBackground)
        .onAppear { store.processViewAppeared() }
        .onDisappear { store.processViewDisappeared() }
    }

    private func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value < 1 ? "0" : RateFormatter.string(bytesPerSecond: value)
    }
}
