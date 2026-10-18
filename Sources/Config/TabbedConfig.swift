import CoreGraphics
import Foundation

/// Keyboard-shortcut preferences, sourced from `~/.config/tabbed.toml`.
struct ShortcutSettings: Equatable {
    /// Master switch for all keyboard shortcuts.
    var enabled: Bool
    /// Modifier(s) held alongside the number / Tab keys.
    var modifiers: CGEventFlags
    /// `modifier`+1…9 selects the Nth tab in the focused group.
    var selectByNumber: Bool
    /// `modifier`+Tab / `modifier`+Shift+Tab cycle through the focused group.
    var cycle: Bool

    static let `default` = ShortcutSettings(
        enabled: true,
        modifiers: .maskAlternate,
        selectByNumber: true,
        cycle: true
    )
}

/// Tab strip colour scheme.
enum StripTheme: String, Equatable {
    case system, dark, light
}

/// Top-level user configuration.
struct TabbedConfig: Equatable {
    var shortcuts: ShortcutSettings
    /// Modifier(s) held while dragging a window onto another to tab it.
    var dragModifiers: CGEventFlags
    var theme: StripTheme

    static let `default` = TabbedConfig(shortcuts: .default, dragModifiers: .maskCommand, theme: .system)
}

extension TabbedConfig {
    /// `~/.config/tabbed.toml`, or the path in `TABBED_CONFIG` when set.
    static var configURL: URL {
        if let override = ProcessInfo.processInfo.environment["TABBED_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/tabbed.toml")
    }

    /// Write the documented default config to `configURL` if no file exists yet,
    /// so the options are discoverable out of the box. Returns the URL.
    @discardableResult
    static func ensureFileExists() -> URL {
        let url = configURL
        let fm = FileManager.default
        guard !fm.fileExists(atPath: url.path) else { return url }
        try? fm.createDirectory(at: url.deletingLastPathComponent(),
                                withIntermediateDirectories: true)
        try? template.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Load and parse the config file, falling back to defaults when it is
    /// missing or unreadable. Unknown or malformed keys are ignored so a
    /// partial file still applies the values it does set.
    static func load() -> TabbedConfig {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return .default
        }
        return parse(text)
    }

    static func parse(_ text: String) -> TabbedConfig {
        let tables = TOML.parse(text)
        let keybindings = tables["keybindings"] ?? [:]

        var shortcuts = ShortcutSettings.default
        if let value = keybindings["enabled"]?.boolValue {
            shortcuts.enabled = value
        }
        if let value = keybindings["select_by_number"]?.boolValue {
            shortcuts.selectByNumber = value
        }
        if let value = keybindings["cycle"]?.boolValue {
            shortcuts.cycle = value
        }
        if let raw = keybindings["modifier"]?.stringValue,
           let modifiers = parseModifiers(raw) {
            shortcuts.modifiers = modifiers
        }

        var config = TabbedConfig.default
        config.shortcuts = shortcuts
        if let raw = tables["drag"]?["modifier"]?.stringValue,
           let modifiers = parseModifiers(raw) {
            config.dragModifiers = modifiers
        }
        if let raw = tables["appearance"]?["theme"]?.stringValue,
           let theme = StripTheme(rawValue: raw.lowercased()) {
            config.theme = theme
        }
        return config
    }

    /// The documented default file, written on first launch.
    static let template = """
    # Tabbed configuration — ~/.config/tabbed.toml
    # Edit, then choose "Reload Configuration" from the menu bar to apply.

    [keybindings]
    # Master switch for all keyboard shortcuts.
    enabled = true

    # Modifier held with the keys below. Combine with "+", e.g. "ctrl+shift".
    # Recognised: alt, ctrl, cmd, shift, fn.
    modifier = "alt"

    # modifier + 1..9 jumps to the Nth window in the focused tab group.
    select_by_number = true

    # modifier + Tab / modifier + Shift + Tab cycle through the group.
    cycle = true

    [drag]
    # Hold this while dragging a window onto another to tab them together.
    # Same names as above, e.g. "cmd", "ctrl+alt".
    modifier = "cmd"

    [appearance]
    # Tab strip colours: "system" follows macOS, or force "dark" / "light".
    theme = "system"

    """

    /// Translate a string like `"alt"` or `"ctrl+shift"` into event flags.
    /// Returns nil if any token is unrecognised, so the caller keeps its default.
    static func parseModifiers(_ text: String) -> CGEventFlags? {
        var flags: CGEventFlags = []
        for token in text.lowercased().split(whereSeparator: { "+, ".contains($0) }) {
            switch token {
            case "alt", "option", "opt": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "fn", "function": flags.insert(.maskSecondaryFn)
            default: return nil
            }
        }
        return flags.isEmpty ? nil : flags
    }
}
