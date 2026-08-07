import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    let hotkeyManager: HotkeyManager

    @State private var keyCombo: KeyCombo = KeyCombo.load() ?? .default
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Screenshot shortcut:")
                    Spacer()
                    Text(keyCombo.displayString)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }
                HotkeyRecorderView(keyCombo: $keyCombo)
                    .frame(height: 28)
                    .onChange(of: keyCombo) { _, newValue in
                        newValue.save()
                        hotkeyManager.register(newValue)
                    }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 400)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently handle — not critical
        }
    }
}
