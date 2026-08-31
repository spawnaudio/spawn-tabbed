import AppKit

extension TabGroupController {
    func syncPanelZOrderWithFrontmostGroupSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.syncPanelZOrderWithFrontmostGroup()
        }
    }

    func syncPanelZOrderWithFrontmostGroup() {
        let focused = focusedGroup()
        let focusedID = focused?.id

        if let focused, isGroupOnActiveSpace(focused) {
            positionPanel(for: focused)
        }

        for group in groups where group.id != focusedID {
            reassertPanelZOrder(for: group, focusedID: focusedID)
        }
    }

    func reassertPanelZOrder(for group: TabGroup, focusedID: UUID? = nil) {
        guard isGroupOnActiveSpace(group) else { return }

        let placement = PanelZOrderPolicy.resolve(
            isCompact: group.useCompact,
            isFocused: (focusedID ?? focusedGroup()?.id) == group.id,
            frontmost: engine.frontmostWindowID(),
            activeWindow: group.activeWindow?.id
        )
        group.panel.apply(placement)
    }
}
