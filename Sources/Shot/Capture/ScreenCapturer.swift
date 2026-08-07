import AppKit
import ScreenCaptureKit

enum ScreenCapturer {
    static func captureAllDisplays() async -> [CaptureResult] {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            return []
        }

        var results: [CaptureResult] = []

        for display in content.displays {
            guard let screen = screenForDisplay(display) else { continue }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * Int(screen.backingScaleFactor)
            config.height = display.height * Int(screen.backingScaleFactor)
            config.showsCursor = false
            config.captureResolution = .best

            guard let image = try? await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            ) else { continue }

            results.append(CaptureResult(
                screen: screen,
                image: image,
                displayID: display.displayID
            ))
        }

        return results
    }

    private static func screenForDisplay(_ display: SCDisplay) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == display.displayID }
    }
}
