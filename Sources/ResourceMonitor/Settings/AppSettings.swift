import Foundation
import Observation
import ServiceManagement

/// User preferences, persisted in UserDefaults.
@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    /// Seconds between samples (0.5, 1 or 2). Takes effect on the next tick.
    var updateInterval: Double { didSet { defaults.set(updateInterval, forKey: "updateInterval") } }
    var processesMineOnly: Bool { didSet { defaults.set(processesMineOnly, forKey: "processesMineOnly") } }

    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?

    private init() {
        defaults.register(defaults: ["updateInterval": 1.0, "processesMineOnly": true])
        updateInterval = defaults.double(forKey: "updateInterval")
        processesMineOnly = defaults.bool(forKey: "processesMineOnly")
        launchAtLogin = SMAppService.mainApp.status == .enabled
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
