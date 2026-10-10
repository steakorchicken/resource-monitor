import SwiftUI

struct SettingsDetailView: View {
    let settings: AppSettings

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DetailHeader(title: "Settings", subtitle: "Resource Monitor 1.0", tint: Theme.textSecondary)

                SectionCard(title: "Sampling") {
                    Picker("Update interval", selection: binding(\.updateInterval)) {
                        Text("0.5 s").tag(0.5)
                        Text("1 s").tag(1.0)
                        Text("2 s").tag(2.0)
                    }
                    .pickerStyle(.segmented).frame(width: 260)
                    Text("How often the charts refresh. Faster updates use a little more CPU. The charts always show the last 60 samples.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }

                SectionCard(title: "Processes") {
                    Toggle("Show only my processes by default", isOn: binding(\.processesMineOnly))
                    Text("Applies the next time the Processes view opens. You can still switch between My and All there.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }

                SectionCard(title: "Startup") {
                    Toggle("Launch at login", isOn: Binding(get: { settings.launchAtLogin },
                                                            set: { settings.setLaunchAtLogin($0) }))
                    if let error = settings.launchAtLoginError {
                        Text(error).font(.system(size: 12)).foregroundStyle(Theme.red)
                    } else {
                        Text("May require the app to be in your Applications folder.")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.windowBackground)
    }
}
