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

        let frontmostWindowID = engine.frontmostWindowID()
        if let active = group.activeWindow,
           (focusedID ?? focusedGroup()?.id) == group.id || frontmostWindowID == active.id {
            group.panel.order(.above, relativeTo: Int(active.id))
            return
        }

        if let frontmostWindowID {
            group.panel.order(.below, relativeTo: Int(frontmostWindowID))
        } else {
            group.panel.orderOut(nil)
        }
    }
}
