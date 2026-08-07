import SwiftUI
import AppKit
import ServiceManagement

struct PreferencesView: View {
    let hotkeyManager: HotkeyManager

    @State private var keyCombo: KeyCombo = KeyCombo.load() ?? .default
    @State private var launchAtLogin = false
    @State private var isHotkeyActive = false

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

                if !isHotkeyActive {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Hotkey inactive — needs Accessibility access")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings") {
                            openAccessibilitySettings()
                        }
                        .font(.caption)
                    }
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
            isHotkeyActive = hotkeyManager.isActive
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            isHotkeyActive = hotkeyManager.isActive
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
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
