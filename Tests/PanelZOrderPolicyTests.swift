import XCTest
@testable import Tabbed

final class PanelZOrderPolicyTests: XCTestCase {
    /// A compact strip rests as a pill inside its own group's frame. When another
    /// app comes to the front, ordering the panel below that window buries the
    /// pill under whatever covers the group. The compact strip must float above
    /// normal windows instead, so it never disappears.
    func test_compactGroupUnderForeignFrontmostWindow_floatsAbove() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: true,
            isFocused: false,
            frontmost: 999,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .float)
    }

    /// With nothing frontmost at all (e.g. focus on the Finder desktop), the old
    /// path ordered unfocused strips out entirely. A compact pill must survive:
    /// nothing is covering it, so making it vanish is pure loss.
    func test_compactGroupWithNoFrontmostWindow_staysVisible() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: true,
            isFocused: false,
            frontmost: nil,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .float)
    }

    /// Compactness, not focus, decides floating: the pill overlaps its own
    /// window either way, so the rule stays uniform while the group is focused.
    func test_compactFocusedGroup_floatsAbove() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: true,
            isFocused: true,
            frontmost: 101,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .float)
    }

    /// Full-width strips sit above their group's frame in empty screen space:
    /// the focused group's strip goes directly above its active tab's window,
    /// as before.
    func test_fullStripFocusedGroup_sitsAboveItsActiveWindow() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: false,
            isFocused: true,
            frontmost: 999,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .aboveActive(101))
    }

    /// An unfocused full-width strip tucks just under the frontmost window.
    func test_fullStripUnfocusedGroup_sitsBelowFrontmostWindow() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: false,
            isFocused: false,
            frontmost: 999,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .belowFrontmost(999))
    }

    /// Nothing is frontmost and the strip is not compact: hide it, as before.
    func test_fullStripUnfocusedGroupWithNoFrontmostWindow_hides() {
        let placement = PanelZOrderPolicy.resolve(
            isCompact: false,
            isFocused: false,
            frontmost: nil,
            activeWindow: 101
        )

        XCTAssertEqual(placement, .hide)
    }
}
