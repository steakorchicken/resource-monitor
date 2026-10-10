import SwiftUI

struct SettingsView: View {
    let settings: AppSettings

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show main window at launch", isOn: binding(\.showMainWindowAtLaunch))
                    .disabled(!settings.showMenuBar)
                Toggle("Show menu bar item", isOn: binding(\.showMenuBar))
                    .disabled(!settings.showDockIcon)
                Toggle("Show Dock icon", isOn: binding(\.showDockIcon))
                    .disabled(!settings.showMenuBar)
                Text("The menu bar item and the Dock icon can't both be off, so there is always a way back in.")
                    .font(.caption).foregroundStyle(.secondary)

                Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                        set: { settings.setLaunchAtLogin($0) }))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(Theme.red)
                }

                Picker("Update interval", selection: binding(\.updateInterval)) {
                    Text("0.5 seconds").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                }
            }

            Section("Menu bar label") {
                ForEach(MenuBarMetric.allCases) { metric in
                    Toggle(metric.title, isOn: Binding(get: { settings.isShown(metric) },
                                                       set: { settings.setMetric(metric, shown: $0) }))
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.windowBackground)
        .frame(width: 440, height: 470)
    }
}
