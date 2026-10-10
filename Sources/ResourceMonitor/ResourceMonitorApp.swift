import SwiftUI
import AppKit
import MonitorCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppSettings.shared
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        if settings.showMainWindowAtLaunch {
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // A `Window` scene always opens at launch on macOS 14, so close it again.
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title == "Resource Monitor" { window.close() }
            }
        }
    }

    /// With the menu bar item hidden, closing the main window quits the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppSettings.shared.showMenuBar
    }
}

@main
struct ResourceMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let settings = AppSettings.shared
    private let store: MonitorStore

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
        // Sampling runs for the whole app lifetime so the menu bar label stays live without a window.
        store = MonitorStore(settings: AppSettings.shared)
        store.start()
    }

    var body: some Scene {
        Window("Resource Monitor", id: "main") {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)

        MenuBarExtra(isInserted: Binding(get: { settings.showMenuBar }, set: { settings.showMenuBar = $0 })) {
            MenuBarPanel(store: store, settings: settings)
        } label: {
            MenuBarLabel(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
                .preferredColorScheme(.dark)
        }
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
                if CommandLine.arguments.contains("--panel-preview") {
                    // Debug aid: shows the menu bar panel in the main window for screenshots.
                    MenuBarPanel(store: store, settings: AppSettings.shared)
                } else {
                switch selection ?? .cpu {
                case .cpu: CPUDetailView(store: store)
                case .memory: MemoryDetailView(store: store)
                case .disk: DiskDetailView(store: store)
                case .network: NetworkDetailView(store: store)
                case .processes: ProcessListView(store: store)
                case .gpu: GPUDetailView(store: store)
                case .sensors: SensorsDetailView(store: store)
                case .battery: BatteryDetailView(store: store)
                }
                }
            }
        }
        .background(Theme.windowBackground)
    }
}
