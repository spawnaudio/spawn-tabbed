import AppKit
import ApplicationServices

extension TabGroupController {
    func setAutoAddNewWindowsToStack(_ enabled: Bool) {
        autoAddNewWindowsToStack = enabled
        AppSettings.autoAddNewWindowsToStack = enabled
        updateWindowCreationObserving()
    }

    /// New-window events are needed for auto-add and for auto-group rules.
    var needsWindowCreationEvents: Bool {
        autoAddNewWindowsToStack || !config.autoGroupBundleIDs.isEmpty
    }

    func updateWindowCreationObserving() {
        if needsWindowCreationEvents {
            observeRunningAppsForWindowCreation()
        } else {
            windowCreationObserver.unobserveAll()
        }
    }

    func setAlwaysUseCompactMode(_ enabled: Bool) {
        alwaysUseCompactMode = enabled
        AppSettings.alwaysUseCompactMode = enabled
        for group in groups where isGroupOnActiveSpace(group) {
            positionPanel(for: group)
            group.panel.show()
        }
    }

    func updateFocusObservers() {
        let pids = Set(groups.flatMap(\.windows).map(\.pid).filter { $0 != ownPID })
        appFocusObserver.setObservedPIDs(
            pids,
            notifications: [
                kAXFocusedWindowChangedNotification,
                kAXMainWindowChangedNotification,
                kAXApplicationActivatedNotification
            ]
        )
    }

    func observeRunningAppsForWindowCreation() {
        for app in NSWorkspace.shared.runningApplications {
            observeAppForWindowCreation(app)
        }
    }

    func observeAppForWindowCreation(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != ownPID else { return }
        windowCreationObserver.observe(
            pid: pid,
            notifications: [kAXWindowCreatedNotification]
        )
    }

    func handleWindowCreated(pid: pid_t, element: AXUIElement) {
        guard pid != ownPID else { return }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        let ruled = bundleID.map(config.autoGroupBundleIDs.contains) ?? false
        guard ruled || (autoAddNewWindowsToStack && !groups.isEmpty) else { return }

        resolveNewWindow(pid: pid, element: element, attemptsRemaining: 3) { [weak self] window in
            guard let self else { return }
            if ruled, self.groupByRule(window) { return }
            if self.autoAddNewWindowsToStack, let target = self.targetGroupForNewWindow() {
                self.add(window, to: target)
            }
        }
    }

    /// Tab a new window with its app's existing group, or with another loose
    /// window of the same app. Returns false if there was nothing to join.
    func groupByRule(_ window: ManagedWindow) -> Bool {
        if let group = groups.first(where: { group in
            isGroupOnActiveSpace(group) && group.windows.contains { $0.appBundleID == window.appBundleID }
        }) {
            add(window, to: group)
            return true
        }
        let sibling = engine.onScreenWindowFrames(excluding: [window.id])
            .first { $0.pid == window.pid && group(containing: $0.id) == nil }
        guard let sibling, let target = engine.managedWindow(id: sibling.id, pid: sibling.pid) else {
            return false
        }
        formGroup(dragged: window, target: target)
        return true
    }

    /// AX often reports a window before it is on screen; retry briefly.
    func resolveNewWindow(pid: pid_t, element: AXUIElement, attemptsRemaining: Int,
                          then handle: @escaping (ManagedWindow) -> Void) {
        let candidates = engine.candidateWindowElements(from: element, pid: pid)
        let onScreen = Set(engine.onScreenWindowFrames(excluding: []).map { $0.id })
        let resolved = candidates.compactMap { engine.managedWindow(from: $0, pid: pid) }
        if let window = resolved.first(where: { group(containing: $0.id) == nil && onScreen.contains($0.id) }) {
            handle(window)
            return
        }
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.resolveNewWindow(pid: pid, element: element,
                                   attemptsRemaining: attemptsRemaining - 1, then: handle)
        }
    }

    func targetGroupForNewWindow() -> TabGroup? {
        focusedGroup() ?? groups.last
    }
}
