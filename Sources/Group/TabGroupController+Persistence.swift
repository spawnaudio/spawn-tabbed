import AppKit

extension TabGroupController {
    func saveGroups() {
        guard !isQuitting else { return }
        store.saveGroups(groups.map { group in
            GroupStore.SavedGroup(
                windows: group.windows.map { .init(id: $0.id, pid: $0.pid) },
                activeIndex: group.activeIndex,
                frame: group.contentFrame
            )
        })
    }

    /// Rebuild groups saved by a previous run. Also recovers tabs left parked
    /// off-screen if Tabbed crashed.
    func restoreSavedGroups() {
        for saved in store.loadGroups() {
            let activeRef = saved.windows.indices.contains(saved.activeIndex)
                ? saved.windows[saved.activeIndex] : nil
            let windows = saved.windows.compactMap { ref -> ManagedWindow? in
                guard group(containing: ref.id) == nil else { return nil }
                return engine.managedWindow(id: ref.id, pid: ref.pid)
            }
            guard windows.count >= 2 else {
                // Not enough left to group; put any survivor back in view.
                windows.forEach { engine.setFrame(saved.frame, of: $0) }
                continue
            }
            let activeIndex = windows.firstIndex { $0.id == activeRef?.id } ?? 0
            let group = TabGroup(
                windows: windows,
                activeIndex: activeIndex,
                contentFrame: saved.frame,
                spaceID: engine.spaceID(of: windows[activeIndex])
            )
            wire(group)
            groups.append(group)
            observeWindows(in: group)
            applyLayout(for: group)
        }
        updateFocusObservers()
        saveGroups()
    }
}
