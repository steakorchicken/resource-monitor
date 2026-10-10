import SwiftUI
import AppKit
import MonitorCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct ResourceMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let store = MonitorStore()

    init() {
        // `ResourceMonitor --dump [ticks]` prints raw samples to stdout and exits (for sanity checks).
        if let i = CommandLine.arguments.firstIndex(of: "--dump") {
            let ticks = CommandLine.arguments.dropFirst(i + 1).first.flatMap(Int.init) ?? 3
            let sampler = SystemSampler()
            for _ in 0..<ticks {
                Thread.sleep(forTimeInterval: 1)
                print(sampler.sample())
            }
            exit(0)
        }
    }

    var body: some Scene {
        Window("Resource Monitor", id: "main") {
            RootView()
                .environment(store)
                .task { store.start() }
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
    }
}

struct RootView: View {
    @Environment(MonitorStore.self) private var store
    // `@State` is a macro in the macOS 27 SDK and its plugin is missing from the
    // Command Line Tools, so use the State type directly.
    private var _selection = State<SidebarItem?>(initialValue: Self.initialSection)
    /// `--section memory` opens that section first (handy for screenshots).
    private static var initialSection: SidebarItem {
        guard let i = CommandLine.arguments.firstIndex(of: "--section"),
              let name = CommandLine.arguments.dropFirst(i + 1).first?.lowercased(),
              let item = SidebarItem.allCases.first(where: { $0.rawValue.lowercased() == name }) else { return .cpu }
        return item
    }
    private var selection: SidebarItem? { _selection.wrappedValue }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: _selection.projectedValue, store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack {
                Theme.windowBackground.ignoresSafeArea()
                switch selection ?? .cpu {
                case .cpu: CPUDetailView(store: store)
                case .memory: MemoryDetailView(store: store)
                case .disk: DiskDetailView(store: store)
                case .network: NetworkDetailView(store: store)
                case .processes: ProcessListView(store: store)
                default:
                    Text("Coming in a later phase").foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .background(Theme.windowBackground)
    }
}
