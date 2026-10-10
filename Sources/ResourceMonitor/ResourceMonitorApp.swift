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
    private var _selection = State<SidebarItem?>(initialValue: .cpu)
    private var selection: SidebarItem? { _selection.wrappedValue }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: _selection.projectedValue)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack {
                Theme.windowBackground.ignoresSafeArea()
                DebugReadout(item: selection ?? .cpu, store: store)
            }
        }
        .background(Theme.windowBackground)
    }
}
