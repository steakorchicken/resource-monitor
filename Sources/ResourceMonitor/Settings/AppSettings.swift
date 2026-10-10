import Foundation
import Observation
import AppKit
import ServiceManagement

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case cpu, memory, network, gpu, temperature
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Network (↓↑)"
        case .gpu: "GPU"
        case .temperature: "Temperature"
        }
    }
}

/// User preferences, persisted in UserDefaults.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var showMainWindowAtLaunch: Bool { didSet { defaults.set(showMainWindowAtLaunch, forKey: "showMainWindowAtLaunch") } }
    var showMenuBar: Bool {
        didSet {
            defaults.set(showMenuBar, forKey: "showMenuBar")
            if !showMenuBar { showMainWindowAtLaunch = true; showDockIcon = true }   // always keep a way in
        }
    }
    var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: "showDockIcon")
            applyActivationPolicy()
        }
    }
    var updateInterval: Double { didSet { defaults.set(updateInterval, forKey: "updateInterval") } }
    var menuBarMetrics: Set<String> { didSet { defaults.set(Array(menuBarMetrics), forKey: "menuBarMetrics") } }

    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?

    private init() {
        defaults.register(defaults: [
            "showMainWindowAtLaunch": true, "showMenuBar": true, "showDockIcon": true,
            "updateInterval": 1.0, "menuBarMetrics": ["cpu", "memory"],
        ])
        showMainWindowAtLaunch = defaults.bool(forKey: "showMainWindowAtLaunch")
        showMenuBar = defaults.bool(forKey: "showMenuBar")
        showDockIcon = defaults.bool(forKey: "showDockIcon")
        updateInterval = defaults.double(forKey: "updateInterval")
        menuBarMetrics = Set(defaults.stringArray(forKey: "menuBarMetrics") ?? ["cpu", "memory"])
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon { NSApp.activate(ignoringOtherApps: true) }
    }

    func isShown(_ metric: MenuBarMetric) -> Bool { menuBarMetrics.contains(metric.rawValue) }

    func setMetric(_ metric: MenuBarMetric, shown: Bool) {
        if shown { menuBarMetrics.insert(metric.rawValue) } else { menuBarMetrics.remove(metric.rawValue) }
    }

    /// Best effort: registration can fail (e.g. when the app is not in /Applications).
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
