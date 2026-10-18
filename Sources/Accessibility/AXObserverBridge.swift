import ApplicationServices
import Foundation

@MainActor
final class AXObserverBridge {
    var onEvent: ((WindowID, String) -> Void)?

    private struct Observation {
        let observer: AXObserver
        let source: CFRunLoopSource
        let element: AXUIElement
    }

    private var observations: [WindowID: Observation] = [:]

    func observe(_ window: ManagedWindow) {
        guard observations[window.id] == nil else { return }

        var observer: AXObserver?
        guard AXObserverCreate(window.pid, Self.callback, &observer) == .success,
              let observer else {
            return
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in Self.notifications {
            AXObserverAddNotification(observer, window.element, notification as CFString, refcon)
        }

        let source = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        observations[window.id] = Observation(observer: observer, source: source, element: window.element)
    }

    /// Match by element identity because destroyed windows may not resolve by id.
    private func windowID(for element: AXUIElement) -> WindowID? {
        for (id, observation) in observations where CFEqual(observation.element, element) {
            return id
        }
        return nil
    }

    func unobserve(_ id: WindowID) {
        guard let observation = observations.removeValue(forKey: id) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), observation.source, .commonModes)
    }

    private static let notifications = [
        kAXMovedNotification,
        kAXResizedNotification,
        kAXUIElementDestroyedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXTitleChangedNotification
    ]

    private static let callback: AXObserverCallback = { _, element, notification, refcon in
        guard let refcon else { return }

        MainActor.assumeIsolated {
            let bridge = Unmanaged<AXObserverBridge>.fromOpaque(refcon).takeUnretainedValue()
            guard let windowID = bridge.windowID(for: element) else { return }
            bridge.onEvent?(windowID, notification as String)
        }
    }
}
