import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    convenience init(hotkeyManager: HotkeyManager) {
        let prefsView = PreferencesView(hotkeyManager: hotkeyManager)
        let hostingController = NSHostingController(rootView: prefsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "A-Shot Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 250))
        window.center()

        self.init(window: window)
    }
}
