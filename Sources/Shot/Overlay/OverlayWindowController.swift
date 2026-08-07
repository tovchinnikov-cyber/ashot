import AppKit

final class OverlayWindowController: OverlayViewDelegate {
    private var overlayWindows: [OverlayWindow] = []
    private var isActive = false
    private var escapeMonitor: Any?
    private var previouslyActiveApp: NSRunningApplication?

    func beginCapture() {
        guard !isActive else { return }
        isActive = true
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication

        Task { @MainActor in
            let captures = await ScreenCapturer.captureAllDisplays()
            guard !captures.isEmpty else {
                isActive = false
                if !Permissions.hasScreenCapture {
                    showScreenCapturePermissionAlert()
                }
                return
            }

            for capture in captures {
                let window = OverlayWindow(screen: capture.screen)
                let overlayView = OverlayView(
                    frame: NSRect(origin: .zero, size: capture.screen.frame.size),
                    capturedImage: capture.image,
                    backingScaleFactor: capture.screen.backingScaleFactor
                )
                overlayView.delegate = self
                window.contentView = overlayView
                overlayWindows.append(window)
            }

            installEscapeMonitor()

            NSApp.activate(ignoringOtherApps: true)

            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            for window in overlayWindows {
                window.makeKeyAndOrderFront(nil)
            }
            NSAnimationContext.endGrouping()

            overlayWindows.first?.makeKey()
        }
    }

    private func showScreenCapturePermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "A-Shot needs Screen Recording access to take screenshots. Grant it in System Settings → Privacy & Security → Screen Recording."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func dismiss() {
        removeEscapeMonitor()
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        isActive = false
        previouslyActiveApp?.activate()
        previouslyActiveApp = nil
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 0x35, let self else { return event }
            // If a text annotation is being typed, Escape should only cancel
            // that instead of closing the whole capture overlay.
            let overlayViews = self.overlayWindows.compactMap { $0.contentView as? OverlayView }
            if overlayViews.contains(where: { $0.cancelTextEntryIfActive() }) {
                return nil
            }
            self.dismiss()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    // MARK: - OverlayViewDelegate

    func overlayViewDidFinishSelection(_ view: OverlayView, rect: NSRect) {
        dismiss()
    }

    func overlayViewDidCancel(_ view: OverlayView) {
        dismiss()
    }
}
