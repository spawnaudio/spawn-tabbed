import AppKit
import ApplicationServices

/// Accessibility-backed implementation of `WindowEngine`.
@MainActor
final class AXWindowEngine: WindowEngine {
    private let spaces = SpacesService()
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func window(at point: CGPoint, excluding: Set<WindowID>) -> ManagedWindow? {
        for window in WindowServerSnapshot.onScreenWindows(excludingOwnPID: ownPID, excluding: excluding) {
            guard window.frame.contains(point),
                  let managed = managedWindow(id: window.id, pid: window.pid, ownerInfo: window.ownerInfo) else {
                continue
            }
            return managed
        }

        return nil
    }

    func onScreenWindowFrames(excluding: Set<WindowID>) -> [WindowFrame] {
        WindowServerSnapshot.onScreenWindows(excludingOwnPID: ownPID, excluding: excluding).compactMap { window in
            // Skip tiny utility/overlay windows that aren't meaningful drop targets.
            guard window.frame.width >= 80, window.frame.height >= 80 else { return nil }
            return WindowFrame(id: window.id, pid: window.pid, frame: window.frame)
        }
    }

    func managedWindow(from element: AXUIElement, pid: pid_t) -> ManagedWindow? {
        guard pid != ownPID, isStandardWindow(element) else { return nil }

        var resolved = CGWindowID(0)
        guard _AXUIElementGetWindow(element, &resolved) == .success,
              resolved != 0 else {
            return nil
        }

        let runningApp = NSRunningApplication(processIdentifier: pid)
        let title = copyStringAttribute(kAXTitleAttribute, from: element) ?? "Untitled"
        return ManagedWindow(
            id: resolved,
            pid: pid,
            element: element,
            title: title.isEmpty ? "Untitled" : title,
            appName: runningApp?.localizedName ?? "Unknown",
            appBundleID: runningApp?.bundleIdentifier
        )
    }

    func frame(of window: ManagedWindow) -> CGRect? {
        guard let position = copyCGPointAttribute(kAXPositionAttribute, from: window.element),
              let size = copyCGSizeAttribute(kAXSizeAttribute, from: window.element) else {
            return nil
        }

        return CoordinateConverter.appKitFrame(fromCG: CGRect(origin: position, size: size))
    }

    func windowServerFrame(of id: WindowID) -> CGRect? {
        WindowServerSnapshot.window(id: id)?.frame
    }

    func focusedOrMainWindowID(for pid: pid_t) -> WindowID? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1.0)

        if let focused = copyAXElementAttribute(kAXFocusedWindowAttribute, from: appElement),
           let id = windowID(of: focused) {
            return id
        }
        if let main = copyAXElementAttribute(kAXMainWindowAttribute, from: appElement),
           let id = windowID(of: main) {
            return id
        }
        return nil
    }

    private func windowID(of element: AXUIElement) -> WindowID? {
        var resolved = CGWindowID(0)
        guard _AXUIElementGetWindow(element, &resolved) == .success,
              resolved != 0 else {
            return nil
        }
        return resolved
    }

    func frontmostWindowID() -> WindowID? {
        WindowServerSnapshot.frontmostVisibleWindow(excludingOwnPID: ownPID)?.id
    }

    func candidateWindowElements(from element: AXUIElement, pid: pid_t) -> [AXUIElement] {
        var candidates = [element]
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1.0)

        if let focused = copyAXElementAttribute(kAXFocusedWindowAttribute, from: appElement) {
            candidates.append(focused)
        }
        if let main = copyAXElementAttribute(kAXMainWindowAttribute, from: appElement) {
            candidates.append(main)
        }
        return candidates
    }

    func setFrame(_ frame: CGRect, of window: ManagedWindow) {
        let cgFrame = CoordinateConverter.cgFrame(fromAppKit: frame)
        setCGSizeAttribute(kAXSizeAttribute, value: cgFrame.size, on: window.element)
        setCGPointAttribute(kAXPositionAttribute, value: cgFrame.origin, on: window.element)
    }

    func raise(_ window: ManagedWindow) {
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    func activate(_ window: ManagedWindow) {
        let appElement = AXUIElementCreateApplication(window.pid)
        AXUIElementSetMessagingTimeout(appElement, 1.0)
        AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, window.element)
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        raise(window)
        NSRunningApplication(processIdentifier: window.pid)?.activate(options: [])
    }

    func isAlive(_ window: ManagedWindow) -> Bool {
        guard NSRunningApplication(processIdentifier: window.pid) != nil else { return false }
        var resolved = CGWindowID(0)
        return _AXUIElementGetWindow(window.element, &resolved) == .success && resolved == window.id
    }

    func refreshTitle(_ window: ManagedWindow) -> String {
        if let title = copyStringAttribute(kAXTitleAttribute, from: window.element), !title.isEmpty {
            window.title = title
        }
        return window.title
    }

    func spaceID(of window: ManagedWindow) -> UInt64? {
        return spaces.spaceID(forWindow: window.id)
    }

    func activeSpaceID() -> UInt64? { spaces.activeSpaceID() }

    func move(_ window: ManagedWindow, toSpaceOf reference: ManagedWindow) {
        spaces.move(window: window.id, toSpaceOf: reference.id)
    }

    private func managedWindow(id: WindowID, pid: pid_t, ownerInfo: [String: Any]) -> ManagedWindow? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 1.0)

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return nil
        }

        for element in elements {
            var resolved = CGWindowID(0)
            guard _AXUIElementGetWindow(element, &resolved) == .success, resolved == id else {
                continue
            }
            guard isStandardWindow(element) else { return nil }

            let runningApp = NSRunningApplication(processIdentifier: pid)
            let title = copyStringAttribute(kAXTitleAttribute, from: element)
                ?? (ownerInfo[kCGWindowName as String] as? String)
                ?? "Untitled"
            let appName = runningApp?.localizedName
                ?? (ownerInfo[kCGWindowOwnerName as String] as? String)
                ?? "Unknown"

            return ManagedWindow(
                id: id,
                pid: pid,
                element: element,
                title: title.isEmpty ? "Untitled" : title,
                appName: appName,
                appBundleID: runningApp?.bundleIdentifier
            )
        }

        return nil
    }

    private func isStandardWindow(_ element: AXUIElement) -> Bool {
        guard copyStringAttribute(kAXRoleAttribute, from: element) == kAXWindowRole else {
            return false
        }
        return copyStringAttribute(kAXSubroleAttribute, from: element) == kAXStandardWindowSubrole
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func copyAXElementAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func copyCGPointAttribute(_ attribute: String, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func copyCGSizeAttribute(_ attribute: String, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }

    private func setCGPointAttribute(_ attribute: String, value: CGPoint, on element: AXUIElement) {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgPoint, &mutableValue) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

    private func setCGSizeAttribute(_ attribute: String, value: CGSize, on element: AXUIElement) {
        var mutableValue = value
        guard let axValue = AXValueCreate(.cgSize, &mutableValue) else { return }
        AXUIElementSetAttributeValue(element, attribute as CFString, axValue)
    }

}
