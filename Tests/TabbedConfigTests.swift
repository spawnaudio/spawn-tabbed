import CoreGraphics
import XCTest
@testable import Tabbed

final class TOMLTests: XCTestCase {
    func testParsesTablesKeysAndComments() {
        let toml = """
        # a leading comment
        rootKey = "top"

        [keybindings]
        enabled = true      # inline comment
        modifier = "ctrl+shift"
        """

        let tables = TOML.parse(toml)
        XCTAssertEqual(tables[""]?["rootKey"], .string("top"))
        XCTAssertEqual(tables["keybindings"]?["enabled"], .bool(true))
        XCTAssertEqual(tables["keybindings"]?["modifier"], .string("ctrl+shift"))
    }

    func testHashInsideStringIsNotAComment() {
        let tables = TOML.parse(#"label = "a # b""#)
        XCTAssertEqual(tables[""]?["label"], .string("a # b"))
    }
}

final class TabbedConfigTests: XCTestCase {
    func testDefaultsWhenSectionMissing() {
        let config = TabbedConfig.parse("# nothing here\n")
        XCTAssertEqual(config, .default)
    }

    func testPartialFileKeepsDefaultsForUnsetKeys() {
        let config = TabbedConfig.parse("""
        [keybindings]
        cycle = false
        """)
        // Only `cycle` overridden; the rest stay at defaults.
        XCTAssertFalse(config.shortcuts.cycle)
        XCTAssertTrue(config.shortcuts.enabled)
        XCTAssertTrue(config.shortcuts.selectByNumber)
        XCTAssertEqual(config.shortcuts.modifiers, .maskAlternate)
    }

    func testParsesModifierString() {
        let config = TabbedConfig.parse("""
        [keybindings]
        modifier = "ctrl+shift"
        """)
        XCTAssertEqual(config.shortcuts.modifiers, [.maskControl, .maskShift])
    }

    func testModifierAliasesAndSeparators() {
        XCTAssertEqual(TabbedConfig.parseModifiers("option"), .maskAlternate)
        XCTAssertEqual(TabbedConfig.parseModifiers("command"), .maskCommand)
        XCTAssertEqual(TabbedConfig.parseModifiers("cmd, shift"), [.maskCommand, .maskShift])
    }

    func testUnknownModifierFallsBack() {
        // An unrecognised token yields nil, so parse() keeps the default modifier.
        XCTAssertNil(TabbedConfig.parseModifiers("hyper"))
        let config = TabbedConfig.parse("""
        [keybindings]
        modifier = "hyper"
        """)
        XCTAssertEqual(config.shortcuts.modifiers, .maskAlternate)
    }
}

final class TabbedConfigDragAndThemeTests: XCTestCase {
    func testDragModifierAndThemeParse() {
        let config = TabbedConfig.parse("""
        [drag]
        modifier = "ctrl+alt"
        [appearance]
        theme = "Light"
        """)
        XCTAssertEqual(config.dragModifiers, [.maskControl, .maskAlternate])
        XCTAssertEqual(config.theme, .light)
    }

    func testUnknownValuesKeepDefaults() {
        let config = TabbedConfig.parse("""
        [drag]
        modifier = "hyper"
        [appearance]
        theme = "purple"
        """)
        XCTAssertEqual(config.dragModifiers, .maskCommand)
        XCTAssertEqual(config.theme, .system)
    }

    func testTemplateParsesToDefaults() {
        XCTAssertEqual(TabbedConfig.parse(TabbedConfig.template), .default)
    }
}
