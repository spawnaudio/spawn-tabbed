import AppKit
import ApplicationServices

/// A real OS window plus the identity needed for AX and Spaces calls.
@MainActor
final class ManagedWindow {
    let id: WindowID
    let pid: pid_t
    let element: AXUIElement
    var title: String
    var appName: String
    var appBundleID: String?

    init(id: WindowID, pid: pid_t, element: AXUIElement,
         title: String, appName: String, appBundleID: String?) {
        self.id = id
        self.pid = pid
        self.element = element
        self.title = title
        self.appName = appName
        self.appBundleID = appBundleID
    }

    var descriptor: TabDescriptor {
        TabDescriptor(id: id, title: title, appName: appName,
                      appBundleID: appBundleID, pid: pid)
    }
}

/// Static window-server snapshot used for drag hit-testing.
struct WindowFrame {
    let id: WindowID
    let pid: pid_t
    let frame: CGRect
}

/// Window-system boundary backed by Accessibility and private CGS Spaces APIs.
@MainActor
protocol WindowEngine: AnyObject {
    /// Frontmost manageable window under `point`, excluding app panels.
    func window(at point: CGPoint, excluding: Set<WindowID>) -> ManagedWindow?

    /// On-screen standard windows, front to back.
    func onScreenWindowFrames(excluding: Set<WindowID>) -> [WindowFrame]

    /// Resolve a live AX window element into the app model.
    func managedWindow(from element: AXUIElement, pid: pid_t) -> ManagedWindow?

    /// Resolve a window by id within its owning app, if it still exists.
    func managedWindow(id: WindowID, pid: pid_t) -> ManagedWindow?

    /// Current frame in AppKit screen coordinates.
    func frame(of window: ManagedWindow) -> CGRect?

    /// Live frame from the window server, fresher than AX during title-bar drags.
    func windowServerFrame(of id: WindowID) -> CGRect?

    /// Focused or main window id for an app process, if AX can resolve it.
    func focusedOrMainWindowID(for pid: pid_t) -> WindowID?

    /// Frontmost visible standard-layer window from the window server.
    func frontmostWindowID() -> WindowID?

    /// Candidate concrete windows for a newly-created AX window notification.
    func candidateWindowElements(from element: AXUIElement, pid: pid_t) -> [AXUIElement]

    /// Move/resize the window in AppKit screen coordinates.
    func setFrame(_ frame: CGRect, of window: ManagedWindow)

    func raise(_ window: ManagedWindow)
    func activate(_ window: ManagedWindow)
    /// Press the window's close button, as if the user clicked it.
    func close(_ window: ManagedWindow)
    func isAlive(_ window: ManagedWindow) -> Bool
    func refreshTitle(_ window: ManagedWindow) -> String

    func spaceID(of window: ManagedWindow) -> UInt64?
    func activeSpaceID() -> UInt64?
    func move(_ window: ManagedWindow, toSpaceOf reference: ManagedWindow)
}
