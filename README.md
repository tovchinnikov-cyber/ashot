# A-Shot

A native screenshot tool for Mac (Apple Silicon) — a free Lightshot/Flameshot alternative, without Electron and without lag. Built with Swift + AppKit + ScreenCaptureKit.

**Free. No telemetry, no ads, no account.**

## Features

- Global hotkey (default `⌘⇧S`, customizable) — works even when another app is focused, including during a Zoom/Teams call
- Resizable region selection with drag handles
- Annotations: arrows, rectangles, text
- One-click copy to clipboard, or `⌘C`
- Multi-monitor support
- Launch at login (optional)

## Installation

1. Download `A-Shot-*.dmg` from the [Releases](../../releases) page
2. Open the DMG, drag `A-Shot.app` into `Applications`
3. On first launch, macOS will show a Gatekeeper warning ("Apple could not verify this app") — this is expected: the app is ad-hoc signed, not signed with a paid Apple Developer ID. To allow it:
   - Try opening the app (it will be blocked)
   - Open **System Settings → Privacy & Security → Security**
   - Find A-Shot and click **Open Anyway**
4. The first time you use the hotkey, macOS will ask for **Accessibility** and **Screen Recording** permissions — both are required for hotkey interception and screen capture, allow them

## Requirements

macOS 15+ (Apple Silicon)

## Building from source

```
make build      # debug build
make bundle      # release + ad-hoc signed .app
make dmg         # .app + .dmg installer
```

## License

MIT — see [LICENSE](LICENSE)
