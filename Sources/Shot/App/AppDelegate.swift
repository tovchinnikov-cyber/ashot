import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private var overlayController: OverlayWindowController!
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Permissions.requestAccessibilityIfNeeded()

        overlayController = OverlayWindowController()

        statusBarController = StatusBarController(
            onCapture: { [weak self] in self?.beginCapture() },
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: { NSApp.terminate(nil) }
        )

        hotkeyManager = HotkeyManager()
        hotkeyManager.onHotkeyPressed = { [weak self] in self?.beginCapture() }
        let combo = KeyCombo.load() ?? KeyCombo.default
        hotkeyManager.register(combo)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func beginCapture() {
        overlayController.beginCapture()
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(hotkeyManager: hotkeyManager)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
