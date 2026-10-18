import ApplicationServices
import XCTest
@testable import Tabbed

@MainActor
final class Phase3Tests: XCTestCase {
    private func window(_ id: WindowID, pid: pid_t = 1, bundle: String? = nil) -> ManagedWindow {
        ManagedWindow(id: id, pid: pid, element: AXUIElementCreateApplication(pid),
                      title: "w\(id)", appName: "App", appBundleID: bundle)
    }

    func test_groupsSurviveRestart() {
        let engine = FakeEngine()
        let first = isolatedController(engine)
        let a = window(1), b = window(2)
        engine.frames = [1: CGRect(x: 10, y: 10, width: 500, height: 400), 2: .zero]
        engine.live = [1: a, 2: b]
        first.formGroup(dragged: b, target: a)
        first.restoreAllWindows() // quit: saves, then dissolves

        let second = TabGroupController(engine: engine)
        second.store = first.store
        second.restoreSavedGroups()
        XCTAssertEqual(second.groups.count, 1)
        XCTAssertEqual(second.groups[0].windows.map(\.id), [1, 2])
        XCTAssertEqual(second.groups[0].activeWindow?.id, 2)
        XCTAssertEqual(second.groups[0].contentFrame, CGRect(x: 10, y: 10, width: 500, height: 400))
    }

    func test_restoreSkipsGroupsWhoseWindowsAreGone() {
        let engine = FakeEngine()
        let first = isolatedController(engine)
        engine.frames = [1: CGRect(x: 0, y: 0, width: 300, height: 300), 2: .zero]
        first.formGroup(dragged: window(2), target: window(1))
        first.restoreAllWindows()

        let second = TabGroupController(engine: engine)
        second.store = first.store
        engine.live = [1: window(1)] // window 2's app quit
        second.restoreSavedGroups()
        XCTAssertTrue(second.groups.isEmpty)
    }

    func test_marks_oneLetterPerWindow_andJumpSelectsTab() {
        let engine = FakeEngine()
        let controller = isolatedController(engine)
        engine.frames = [1: CGRect(x: 0, y: 0, width: 300, height: 300), 2: .zero]
        controller.formGroup(dragged: window(2), target: window(1))

        controller.assignMark("a", to: .init(id: 1, pid: 1))
        controller.assignMark("b", to: .init(id: 1, pid: 1))
        XCTAssertNil(controller.marks["a"], "re-tagging moves the mark")
        XCTAssertEqual(controller.groups[0].viewModel.marks[1], "b")

        XCTAssertTrue(controller.keyboardShortcutJumpToMark("b"))
        XCTAssertEqual(controller.groups[0].activeWindow?.id, 1)
        XCTAssertFalse(controller.keyboardShortcutJumpToMark("z"), "unassigned keys pass through")
    }

    func test_rule_groupsNewWindowWithLooseSibling() {
        let engine = FakeEngine()
        let controller = isolatedController(engine)
        let old = window(1, bundle: "com.apple.Terminal")
        let new = window(2, bundle: "com.apple.Terminal")
        engine.frames = [1: CGRect(x: 0, y: 0, width: 300, height: 300), 2: .zero]
        engine.live = [1: old]
        engine.onScreen = [WindowFrame(id: 1, pid: 1, frame: engine.frames[1]!)]

        XCTAssertTrue(controller.groupByRule(new))
        XCTAssertEqual(controller.groups.first?.windows.map(\.id), [1, 2])

        let third = window(3, bundle: "com.apple.Terminal")
        XCTAssertTrue(controller.groupByRule(third), "joins the app's existing group")
        XCTAssertEqual(controller.groups.first?.windows.map(\.id), [1, 2, 3])
    }

    func test_configParsesMarksAndRules() {
        let config = TabbedConfig.parse("""
        [marks]
        enabled = false
        jump = "cmd+ctrl"
        [rules]
        auto_group = "com.apple.Terminal, com.googlecode.iterm2 ,"
        """)
        XCTAssertFalse(config.shortcuts.marks)
        XCTAssertEqual(config.shortcuts.markJump, [.maskCommand, .maskControl])
        XCTAssertEqual(config.autoGroupBundleIDs, ["com.apple.Terminal", "com.googlecode.iterm2"])
    }
}
