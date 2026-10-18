import AppKit
import CoreGraphics

/// Receives keyboard-shortcut intents from the global key tap. Each callback
/// returns `true` when it consumed the shortcut (an eligible focused group
/// existed); the monitor then swallows the key event so the app underneath
/// never sees it.
@MainActor
protocol KeyboardShortcutMonitorDelegate: AnyObject {
    /// Select the tab at `index` (0-based) in the focused group.
    func keyboardShortcutSelectTab(at index: Int) -> Bool
    /// Move to the next (`forward`) or previous tab in the focused group.
    func keyboardShortcutCycleTab(forward: Bool) -> Bool
    /// Tag the focused window with `letter`.
    func keyboardShortcutAssignMark(_ letter: String) -> Bool
    /// Bring forward the window tagged `letter`.
    func keyboardShortcutJumpToMark(_ letter: String) -> Bool
}

/// Global keyDown tap that maps configured chords to tab actions.
@MainActor
final class KeyboardShortcutMonitor {
    weak var delegate: KeyboardShortcutMonitorDelegate?
    private(set) var settings: ShortcutSettings

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Modifier bits we compare against; everything else (caps lock, etc.) is ignored.
    private static let modifierMask: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn
    ]

    /// Virtual key codes for the `1`…`9` number-row keys, in order.
    private static let numberKeyCodes: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let tabKeyCode: Int64 = 48

    /// ANSI virtual key codes for a…z.
    // ponytail: ANSI positions, so marks follow key position on non-QWERTY layouts.
    static let letterKeyCodes: [Int64: String] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g", 4: "h", 34: "i",
        38: "j", 40: "k", 37: "l", 46: "m", 45: "n", 31: "o", 35: "p", 12: "q",
        15: "r", 1: "s", 17: "t", 32: "u", 9: "v", 13: "w", 7: "x", 16: "y", 6: "z"
    ]

    init(settings: ShortcutSettings) {
        self.settings = settings
    }

    func start() {
        guard eventTap == nil, settings.enabled else { return }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[KeyboardShortcutMonitor] failed to create CGEventTap")
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// Re-evaluate against fresh settings, toggling the tap on or off.
    func apply(settings: ShortcutSettings) {
        self.settings = settings
        if settings.enabled {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Event handling

    /// Returns nil to swallow the event, or the event to let it through.
    private func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return event
        }

        guard type == .keyDown, settings.enabled, let delegate else { return event }

        let flags = event.flags.intersection(Self.modifierMask)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let base = settings.modifiers.intersection(Self.modifierMask)

        // modifier + 1…9 → select that tab.
        if settings.selectByNumber, flags == base,
           let index = Self.numberKeyCodes.firstIndex(of: keyCode) {
            return delegate.keyboardShortcutSelectTab(at: index) ? nil : event
        }

        // modifier + Tab → next, modifier + Shift + Tab → previous.
        if settings.cycle, keyCode == Self.tabKeyCode {
            let withShift = base.union(.maskShift)
            if flags == base {
                return delegate.keyboardShortcutCycleTab(forward: true) ? nil : event
            }
            // Only treat Shift as "reverse" when it isn't already part of the base chord.
            if !base.contains(.maskShift), flags == withShift {
                return delegate.keyboardShortcutCycleTab(forward: false) ? nil : event
            }
        }

        // Marks: assign + letter tags, jump + letter recalls.
        if settings.marks, let letter = Self.letterKeyCodes[keyCode] {
            if flags == settings.markAssign.intersection(Self.modifierMask) {
                return delegate.keyboardShortcutAssignMark(letter) ? nil : event
            }
            if flags == settings.markJump.intersection(Self.modifierMask) {
                return delegate.keyboardShortcutJumpToMark(letter) ? nil : event
            }
        }

        return event
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }

        return MainActor.assumeIsolated {
            let monitor = Unmanaged<KeyboardShortcutMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            guard let result = monitor.handle(type: type, event: event) else { return nil }
            return Unmanaged.passUnretained(result)
        }
    }
}
