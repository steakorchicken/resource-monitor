import SwiftUI
import AppKit

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

    var body: some Scene {
        Window("Resource Monitor", id: "main") {
            RootView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1040, height: 700)
    }
}

struct RootView: View {
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
                VStack(spacing: 8) {
                    Text(selection?.rawValue ?? "Resource Monitor")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Nothing here yet")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .background(Theme.windowBackground)
    }
}
