import AppKit

extension TabGroupController: KeyboardShortcutMonitorDelegate {
    /// Activate the tab at `index` in the group the user is currently focused on.
    func keyboardShortcutSelectTab(at index: Int) -> Bool {
        guard let group = focusedGroupOnActiveSpace(),
              group.windows.indices.contains(index) else {
            return false
        }
        // Already active — still consume so the keystroke doesn't reach the app.
        if index != group.activeIndex {
            selectTab(group.windows[index].id, in: group)
        }
        return true
    }

    /// Step to the adjacent tab, wrapping around the ends.
    func keyboardShortcutCycleTab(forward: Bool) -> Bool {
        guard let group = focusedGroupOnActiveSpace(), group.windows.count > 1 else {
            return false
        }
        let count = group.windows.count
        let next = forward
            ? (group.activeIndex + 1) % count
            : (group.activeIndex - 1 + count) % count
        selectTab(group.windows[next].id, in: group)
        return true
    }

    /// The focused group, provided it lives on the space the user is viewing.
    private func focusedGroupOnActiveSpace() -> TabGroup? {
        guard let group = focusedGroup(), isGroupOnActiveSpace(group) else {
            return nil
        }
        return group
    }
}
