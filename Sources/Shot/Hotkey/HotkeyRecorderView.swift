import SwiftUI
import AppKit

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCombo: KeyCombo

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onRecorded = { combo in
            keyCombo = combo
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {}
}

final class HotkeyRecorderNSView: NSView {
    var onRecorded: ((KeyCombo) -> Void)?
    private var isRecording = false
    private var trackingArea: NSTrackingArea?

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .medium)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            heightAnchor.constraint(equalToConstant: 28),
        ])

        updateLabel()
    }

    private func updateLabel() {
        if isRecording {
            label.stringValue = "Press shortcut..."
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            label.stringValue = "Click to record"
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            isRecording = true
            window?.makeFirstResponder(self)
            updateLabel()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 0x35 {
            isRecording = false
            updateLabel()
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) else {
            return
        }

        let combo = KeyCombo(keyCode: event.keyCode, modifierFlags: modifiers.rawValue)
        isRecording = false
        label.stringValue = combo.displayString
        layer?.borderColor = NSColor.separatorColor.cgColor
        onRecorded?(combo)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateLabel()
        return super.resignFirstResponder()
    }
}
