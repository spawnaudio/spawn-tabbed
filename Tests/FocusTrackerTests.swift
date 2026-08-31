import XCTest
@testable import Tabbed

@MainActor
final class FocusTrackerTests: XCTestCase {
    private var groups: [FocusTracker.GroupSnapshot] = []
    private var zOrder: [WindowID] = []
    private var tracker: FocusTracker!
    private var ids: [String: UUID] = [:]

    override func setUp() {
        super.setUp()
        groups = []
        zOrder = []
        ids = [:]
        tracker = FocusTracker(groups: { [weak self] in self?.groups ?? [] },
                               zOrderedWindowIDs: { [weak self] in self?.zOrder ?? [] })
    }

    private func addGroup(_ name: String, activeWindow: WindowID, pid: pid_t) {
        let id = UUID()
        ids[name] = id
        groups.append(FocusTracker.GroupSnapshot(id: id, activeWindowID: activeWindow, pid: pid))
    }

    /// Another app grabs attention (dock bounce, notification) without the user
    /// touching it. The focused group must be the one whose active window is
    /// visually frontmost — the app the user can see — even though the
    /// attention stealer owns no tab and its own window sits on top.
    func test_whenAnotherAppGrabsAttention_focusedGroupIsTheVisuallyFrontmostOne() {
        addGroup("underneath", activeWindow: 101, pid: 200)
        addGroup("visible", activeWindow: 201, pid: 300)
        zOrder = [301, 999, 201, 101]  // 301/999 belong to the stealer, 201 is on top

        tracker.applicationActivated(400)  // stealer's pid, owns no tab

        XCTAssertEqual(tracker.focusedGroupID(), ids["visible"])
    }

    /// The normal case: the frontmost app's focused window is a group's active
    /// tab. The cached answer wins without consulting the window server, even
    /// if a raw z-order walk would name another group first.
    func test_frontmostAppsFocusedWindow_outranksVisualZOrder() {
        addGroup("mine", activeWindow: 101, pid: 200)
        addGroup("other", activeWindow: 201, pid: 300)
        zOrder = [201, 101]  // "other" happens to sit visually on top

        tracker.applicationActivated(200)
        tracker.windowFocused(101, in: 200)

        XCTAssertEqual(tracker.focusedGroupID(), ids["mine"])
    }

    /// Every group is hidden (all minimized, or z-order covered by strangers).
    /// The last group the user actually focused is still the right answer.
    func test_whenNoGroupIsVisible_focusedGroupFallsBackToMostRecent() {
        addGroup("earlier", activeWindow: 101, pid: 200)
        addGroup("later", activeWindow: 201, pid: 300)

        tracker.applicationActivated(300)
        tracker.windowFocused(201, in: 300)
        XCTAssertEqual(tracker.focusedGroupID(), ids["later"])

        // Later: stealer takes attention and the visible order holds no group.
        tracker.applicationActivated(400)
        zOrder = [501, 502]

        XCTAssertEqual(tracker.focusedGroupID(), ids["later"])
    }

    /// The most-recent group's windows are gone (app quit). A stale id must
    /// not come back: the answer is nil, not a ghost.
    func test_staleMostRecent_isNotReturned() {
        addGroup("gone", activeWindow: 101, pid: 200)
        tracker.applicationActivated(200)
        tracker.windowFocused(101, in: 200)
        XCTAssertEqual(tracker.focusedGroupID(), ids["gone"])

        groups = []  // group dissolved
        tracker.applicationActivated(400)
        zOrder = [501]

        XCTAssertNil(tracker.focusedGroupID())
    }
}
