import AppKit

extension TabGroupController {
    func add(_ window: ManagedWindow, to group: TabGroup) {
        if group.contains(window.id) {
            group.activeIndex = group.windows.firstIndex { $0.id == window.id } ?? group.activeIndex
            applyLayout(for: group)
            return
        }

        if let sourceGroup = self.group(containing: window.id), sourceGroup !== group {
            remove(window.id, from: sourceGroup, keepWindowObserved: true)
        }

        if let reference = group.activeWindow,
           let windowSpace = engine.spaceID(of: window),
           let groupSpace = group.spaceID,
           windowSpace != groupSpace {
            engine.move(window, toSpaceOf: reference)
        }

        group.windows.append(window)
        group.activeIndex = group.windows.count - 1
        observeWindows(in: group)
        updateFocusObservers()
        applyLayout(for: group)
    }

    func positionPanel(for group: TabGroup) {
        let compact = group.useCompact
        if group.viewModel.compact != compact {
            group.viewModel.compact = compact
        }
        group.panel.applyLayout(
            compact: compact,
            resting: group.stripFrame,
            expanded: compact ? group.compactExpandedFrame : group.stripFrameAbove
        )
        reassertPanelZOrder(for: group)
    }

    func applyLayout(for group: TabGroup) {
        guard isGroupOnActiveSpace(group), !group.isMinimized else {
            group.panel.hide()
            group.syncViewModel()
            return
        }

        isApplyingLayout = true
        for (index, window) in group.windows.enumerated() {
            _ = engine.refreshTitle(window)
            if index == group.activeIndex {
                engine.setFrame(group.contentFrame, of: window)
            } else {
                parkOffscreen(window)
            }
        }
        if let active = group.activeWindow {
            engine.raise(active)
        }
        isApplyingLayout = false

        positionPanel(for: group)
        group.panel.show()
        group.syncViewModel()
    }

    /// Park inactive tabs out of view without triggering AX clamping.
    private func parkOffscreen(_ window: ManagedWindow) {
        guard let frame = engine.frame(of: window) else { return }
        // The window's own screen first, so it parks where it already is.
        let own = NSScreen.screens.filter { $0.frame.intersects(frame) }
        let rest = NSScreen.screens.filter { !$0.frame.intersects(frame) }
        let screens = (own + rest).map { (frame: $0.frame, visible: $0.visibleFrame) }
        guard let parked = ParkingSpot.frame(for: frame.size, screens: screens) else { return }
        engine.setFrame(parked, of: window)
    }

    func selectTab(_ id: WindowID, in group: TabGroup) {
        guard let idx = group.windows.firstIndex(where: { $0.id == id }) else { return }
        group.activeIndex = idx
        applyLayout(for: group)
        if isGroupOnActiveSpace(group) {
            engine.activate(group.windows[idx])
        }
    }

    /// Move a tab to `index`, keeping the same window active.
    func reorder(_ id: WindowID, to index: Int, in group: TabGroup) {
        guard let from = group.windows.firstIndex(where: { $0.id == id }),
              from != index, group.windows.indices.contains(index) else { return }
        let active = group.activeWindow
        group.windows.insert(group.windows.remove(at: from), at: index)
        if let active, let newIndex = group.windows.firstIndex(where: { $0 === active }) {
            group.activeIndex = newIndex
        }
        group.syncViewModel()
    }

    func untab(_ id: WindowID, from group: TabGroup) {
        guard let window = group.windows.first(where: { $0.id == id }) else { return }
        let base = group.contentFrame
        remove(id, from: group, keepWindowObserved: false)
        let offset: CGFloat = 32
        let size = engine.frame(of: window)?.size ?? base.size
        engine.setFrame(CGRect(x: base.minX + offset, y: base.minY - offset,
                               width: size.width, height: size.height), of: window)
        engine.activate(window)
    }

    func remove(_ id: WindowID, from group: TabGroup, keepWindowObserved: Bool) {
        guard let idx = group.windows.firstIndex(where: { $0.id == id }) else { return }
        if idx == group.activeIndex {
            // The minimised tab is gone; show whichever tab takes its place.
            group.isMinimized = false
        }
        group.windows.remove(at: idx)
        if !keepWindowObserved {
            observer.unobserve(id)
        }

        if group.windows.count <= 1 {
            dissolve(group)
            return
        }

        if idx < group.activeIndex {
            group.activeIndex -= 1
        } else if group.activeIndex >= group.windows.count {
            group.activeIndex = group.windows.count - 1
        }

        applyLayout(for: group)
        updateFocusObservers()
    }

    /// Dissolve every group, returning parked windows to the shared frame.
    func restoreAllWindows() {
        for group in groups {
            dissolve(group)
        }
    }

    func dissolve(_ group: TabGroup) {
        group.panel.hide()
        for window in group.windows {
            observer.unobserve(window.id)
            engine.setFrame(group.contentFrame, of: window)
        }
        groups.removeAll { $0 === group }
        updateFocusObservers()
    }
}
