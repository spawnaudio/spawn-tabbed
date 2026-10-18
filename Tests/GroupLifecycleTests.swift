import ApplicationServices
import XCTest
@testable import Tabbed

/// In-memory window system: frames only, no AX or window server.
@MainActor
private final class FakeEngine: WindowEngine {
    var frames: [WindowID: CGRect] = [:]

    func window(at point: CGPoint, excluding: Set<WindowID>) -> ManagedWindow? { nil }
    func onScreenWindowFrames(excluding: Set<WindowID>) -> [WindowFrame] { [] }
    func managedWindow(from element: AXUIElement, pid: pid_t) -> ManagedWindow? { nil }
    func frame(of window: ManagedWindow) -> CGRect? { frames[window.id] }
    func windowServerFrame(of id: WindowID) -> CGRect? { frames[id] }
    func focusedOrMainWindowID(for pid: pid_t) -> WindowID? { nil }
    func frontmostWindowID() -> WindowID? { nil }
    func candidateWindowElements(from element: AXUIElement, pid: pid_t) -> [AXUIElement] { [] }
    func setFrame(_ frame: CGRect, of window: ManagedWindow) { frames[window.id] = frame }
    func raise(_ window: ManagedWindow) {}
    func activate(_ window: ManagedWindow) {}
    func isAlive(_ window: ManagedWindow) -> Bool { true }
    func refreshTitle(_ window: ManagedWindow) -> String { window.title }
    func spaceID(of window: ManagedWindow) -> UInt64? { nil }
    func activeSpaceID() -> UInt64? { nil }
    func move(_ window: ManagedWindow, toSpaceOf reference: ManagedWindow) {}
}

@MainActor
final class GroupLifecycleTests: XCTestCase {
    private let shared = CGRect(x: 100, y: 100, width: 800, height: 600)
    private var engine: FakeEngine!
    private var controller: TabGroupController!
    private var a: ManagedWindow!
    private var b: ManagedWindow!

    override func setUp() async throws {
        engine = FakeEngine()
        controller = TabGroupController(engine: engine)
        a = window(1)
        b = window(2)
        engine.frames = [1: shared, 2: CGRect(x: 0, y: 0, width: 300, height: 300)]
        controller.formGroup(dragged: b, target: a)
    }

    private func window(_ id: WindowID) -> ManagedWindow {
        ManagedWindow(id: id, pid: 1, element: AXUIElementCreateApplication(1),
                      title: "w\(id)", appName: "App", appBundleID: nil)
    }

    func test_minimisingActiveTab_keepsGroup_andRestoresOnReturn() {
        let group = controller.groups[0]
        controller.handleWindowNotification(id: b.id, notification: kAXWindowMiniaturizedNotification)
        XCTAssertEqual(controller.groups.count, 1)
        XCTAssertTrue(group.isMinimized)

        controller.handleWindowNotification(id: b.id, notification: kAXWindowDeminiaturizedNotification)
        XCTAssertFalse(group.isMinimized)
        XCTAssertEqual(group.windows.map(\.id), [1, 2])
    }

    func test_minimisingInactiveTab_dropsItFromGroup() {
        controller.handleWindowNotification(id: a.id, notification: kAXWindowMiniaturizedNotification)
        XCTAssertTrue(controller.groups.isEmpty, "a two-tab group dissolves when one tab leaves")
    }

    func test_restoreAllWindows_bringsParkedTabsBack() {
        XCTAssertNotEqual(engine.frames[1], shared, "inactive tab is parked")
        controller.restoreAllWindows()
        XCTAssertTrue(controller.groups.isEmpty)
        XCTAssertEqual(engine.frames[1], shared)
        XCTAssertEqual(engine.frames[2], shared)
    }
}
