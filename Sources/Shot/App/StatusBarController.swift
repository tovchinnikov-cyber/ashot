import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem

    init(onCapture: @escaping () -> Void, onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "A-Shot")
        }

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Take Screenshot", action: nil, keyEquivalent: "")
        captureItem.target = nil
        menu.addItem(captureItem)
        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ",")
        menu.addItem(prefsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit A-Shot", action: nil, keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu

        captureItem.representedObject = onCapture
        captureItem.action = #selector(handleAction(_:))
        captureItem.target = self

        prefsItem.representedObject = onPreferences
        prefsItem.action = #selector(handleAction(_:))
        prefsItem.target = self

        quitItem.representedObject = onQuit
        quitItem.action = #selector(handleAction(_:))
        quitItem.target = self
    }

    @objc private func handleAction(_ sender: NSMenuItem) {
        if let action = sender.representedObject as? () -> Void {
            action()
        }
    }
}
