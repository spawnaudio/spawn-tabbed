import Foundation

/// Where a group's strip panel belongs in the window z-order right now.
enum PanelZOrder: Equatable {
    /// Pinned above all normal windows: a compact pill overlaps its own
    /// group's frame, so ordering it below other windows buries it.
    case float
    /// Directly above the group's active tab's window.
    case aboveActive(WindowID)
    /// Directly below the frontmost window.
    case belowFrontmost(WindowID)
    /// Not on screen.
    case hide
}

/// Decides z-order placement from what the user can see. Pure: no AppKit.
enum PanelZOrderPolicy {
    static func resolve(isCompact: Bool,
                        isFocused: Bool,
                        frontmost: WindowID?,
                        activeWindow: WindowID?) -> PanelZOrder {
        if isCompact { return .float }
        if let activeWindow, isFocused || frontmost == activeWindow {
            return .aboveActive(activeWindow)
        }
        if let frontmost { return .belowFrontmost(frontmost) }
        return .hide
    }
}
