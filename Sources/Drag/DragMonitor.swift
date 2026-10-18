import AppKit
import CoreGraphics

/// Reports a modifier-drag window gesture (⌘ by default).
@MainActor
protocol DragMonitorDelegate: AnyObject {
    func dragDidBegin(window: ManagedWindow?, at point: CGPoint)
    func dragDidMove(to point: CGPoint)
    func dragDidEnd(at point: CGPoint)
    func dragDidCancel()
}

/// Global modifier-drag event tap.
@MainActor
final class DragMonitor {
    weak var delegate: DragMonitorDelegate?
    /// Held during a drag to tab windows; `[drag] modifier` in the config.
    var modifiers: CGEventFlags = .maskCommand
    private let engine: WindowEngine
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isTakingOverDrag = false
    private var isMouseDown = false
    private var pendingGesture = false
    private var downPoint: CGPoint = .zero
    private static let dragThreshold: CGFloat = 6

    init(engine: WindowEngine) {
        self.engine = engine
    }

    func start() {
        guard eventTap == nil else { return }

        let mask = Self.mask(for: [
            .leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp,
            .flagsChanged
        ])

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[DragMonitor] failed to create CGEventTap")
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
        isTakingOverDrag = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> CGEvent? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if isTakingOverDrag {
                isTakingOverDrag = false
                isMouseDown = false
                delegate?.dragDidCancel()
            }
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return event
        }

        let point = appKitPoint(fromCGEvent: event)
        let modifierIsDown = event.flags.contains(modifiers)

        switch type {
        case .leftMouseDown:
            isMouseDown = true
            downPoint = point
            pendingGesture = modifierIsDown
            return event

        case .leftMouseDragged:
            if isTakingOverDrag {
                delegate?.dragDidMove(to: point)
                return nil
            }
            if pendingGesture, modifierIsDown,
               hypot(point.x - downPoint.x, point.y - downPoint.y) > Self.dragThreshold {
                pendingGesture = false
                if beginTakeover(at: downPoint) {
                    delegate?.dragDidMove(to: point)
                    return nil
                }
            }
            return event

        case .leftMouseUp:
            isMouseDown = false
            pendingGesture = false
            if isTakingOverDrag {
                isTakingOverDrag = false
                delegate?.dragDidEnd(at: point)
                return nil
            }
            return event

        case .flagsChanged:
            if isTakingOverDrag, !modifierIsDown {
                isTakingOverDrag = false
                delegate?.dragDidCancel()
            } else if !isTakingOverDrag, modifierIsDown, isMouseDown {
                if beginTakeover(at: point) {
                    pendingGesture = false
                    delegate?.dragDidMove(to: point)
                }
            } else if pendingGesture, !modifierIsDown {
                pendingGesture = false
            }
            return event

        default:
            return isTakingOverDrag ? nil : event
        }
    }

    private func beginTakeover(at point: CGPoint) -> Bool {
        let window = engine.window(at: point, excluding: [])
        delegate?.dragDidBegin(window: window, at: point)
        guard window != nil else { return false }
        isTakingOverDrag = true
        return true
    }

    private func appKitPoint(fromCGEvent event: CGEvent) -> CGPoint {
        CoordinateConverter.appKitPoint(fromCG: event.location)
    }

    private static func mask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }

        return MainActor.assumeIsolated {
            let monitor = Unmanaged<DragMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            guard let result = monitor.handle(type: type, event: event) else { return nil }
            return Unmanaged.passUnretained(result)
        }
    }
}
