import AppKit

/// Real windows sharing one frame and one floating tab strip.
@MainActor
final class TabGroup {
    let id = UUID()
    let viewModel = TabGroupViewModel()
    let panel: TabBarPanel

    var windows: [ManagedWindow]
    var activeIndex: Int

    /// Shared content frame in AppKit screen coordinates.
    var contentFrame: CGRect

    var spaceID: UInt64?
    var moveAnchorFrame: CGRect?

    /// The active tab is in the Dock; the strip stays hidden until it returns.
    var isMinimized = false

    init(windows: [ManagedWindow], activeIndex: Int, contentFrame: CGRect, spaceID: UInt64?) {
        self.windows = windows
        self.activeIndex = activeIndex
        self.contentFrame = contentFrame
        self.spaceID = spaceID
        self.panel = TabBarPanel(model: viewModel)
        syncViewModel()
    }

    var activeWindow: ManagedWindow? {
        windows.indices.contains(activeIndex) ? windows[activeIndex] : nil
    }

    func contains(_ id: WindowID) -> Bool {
        windows.contains { $0.id == id }
    }

    /// What the focus tracker sees: the group's active tab, by id and pid.
    var focusSnapshot: FocusTracker.GroupSnapshot? {
        activeWindow.map { FocusTracker.GroupSnapshot(id: id, activeWindowID: $0.id, pid: $0.pid) }
    }

    var hasRoomAbove: Bool {
        let screen = NSScreen.screens.first { $0.frame.intersects(contentFrame) } ?? NSScreen.main
        let ceiling = screen?.visibleFrame.maxY ?? contentFrame.maxY
        return contentFrame.maxY + Theme.stripHeight <= ceiling
    }

    var useCompact: Bool {
        !hasRoomAbove
            || AppSettings.alwaysUseCompactMode
            || ProcessInfo.processInfo.environment["TABBED_FORCE_COMPACT"] != nil
    }

    var stripFrameAbove: CGRect {
        CGRect(x: contentFrame.minX, y: contentFrame.maxY,
               width: contentFrame.width, height: Theme.stripHeight)
    }

    var compactPillFrame: CGRect {
        let height = Theme.stripHeight
        let inset = Theme.compactInset
        let count = CGFloat(max(windows.count, 1))
        let width = min(count * Theme.compactIconSlot + Theme.compactPillPadding * 2,
                        contentFrame.width - inset * 2)
        let x = contentFrame.maxX - width - inset
        let y = contentFrame.maxY - height - inset
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var compactExpandedFrame: CGRect {
        let inset = Theme.compactInset
        return CGRect(x: contentFrame.minX + inset,
                      y: contentFrame.maxY - Theme.stripHeight - inset,
                      width: contentFrame.width - inset * 2,
                      height: Theme.stripHeight)
    }

    var stripFrame: CGRect {
        useCompact ? compactPillFrame : stripFrameAbove
    }

    func syncViewModel() {
        viewModel.tabs = windows.map(\.descriptor)
        viewModel.activeID = activeWindow?.id
    }
}
