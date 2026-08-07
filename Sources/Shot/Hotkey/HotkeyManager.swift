import AppKit

final class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var currentCombo: KeyCombo = .default
    var onHotkeyPressed: (() -> Void)?

    func register(_ combo: KeyCombo) {
        currentCombo = combo
        if eventTap == nil {
            installEventTap()
        }
    }

    func unregister() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        eventTap = nil
        runLoopSource = nil
    }

    // Uses an active CGEventTap (not an NSEvent monitor) so a matching hotkey
    // can be swallowed here instead of also being delivered to the
    // frontmost app (e.g. Teams treating it as "activate focused item").
    private func installEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handle(event: event, type: type)
            },
            userInfo: selfPtr
        ) else {
            NSLog("A-Shot: failed to create hotkey event tap — check Accessibility permission")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            NSLog("A-Shot: failed to create run loop source for hotkey event tap")
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown, let nsEvent = NSEvent(cgEvent: event), matchesCombo(nsEvent) else {
            return Unmanaged.passRetained(event)
        }

        DispatchQueue.main.async { [weak self] in
            self?.onHotkeyPressed?()
        }
        return nil
    }

    private func matchesCombo(_ event: NSEvent) -> Bool {
        let deviceIndependent = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let comboFlags = NSEvent.ModifierFlags(rawValue: currentCombo.modifierFlags).intersection(.deviceIndependentFlagsMask)
        return event.keyCode == currentCombo.keyCode && deviceIndependent == comboFlags
    }

    deinit {
        unregister()
    }
}
