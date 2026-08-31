import AppKit
import ApplicationServices

extension TabGroupController {
    func setAutoAddNewWindowsToStack(_ enabled: Bool) {
        autoAddNewWindowsToStack = enabled
        AppSettings.autoAddNewWindowsToStack = enabled
        if enabled {
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
        guard autoAddNewWindowsToStack, pid != ownPID, !groups.isEmpty else { return }
        resolveAndAutoAddWindow(pid: pid, element: element, attemptsRemaining: 3)
    }

    func resolveAndAutoAddWindow(pid: pid_t, element: AXUIElement, attemptsRemaining: Int) {
        let candidates = engine.candidateWindowElements(from: element, pid: pid)
        let onScreen = Set(engine.onScreenWindowFrames(excluding: []).map { $0.id })
        let window = candidates
            .compactMap { engine.managedWindow(from: $0, pid: pid) }
            .first { group(containing: $0.id) == nil && onScreen.contains($0.id) }

        if let window, let target = targetGroupForNewWindow() {
            add(window, to: target)
            return
        }

        if window != nil {
            return
        }

        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.resolveAndAutoAddWindow(
                pid: pid,
                element: element,
                attemptsRemaining: attemptsRemaining - 1
            )
        }
    }

    func targetGroupForNewWindow() -> TabGroup? {
        focusedGroup() ?? groups.last
    }
}
