import AppKit

extension TabGroupController {
    func observeSpaceChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    /// Wake, unlock, and display changes can drop or misplace strips (upstream #2).
    func observeDisplayChanges() {
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(displayEnvironmentChanged),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(displayEnvironmentChanged),
                              name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(displayEnvironmentChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(displayEnvironmentChanged),
                                                            name: .init("com.apple.screenIsUnlocked"),
                                                            object: nil)
    }

    @objc func displayEnvironmentChanged() {
        // Give the window server a moment to settle after wake/unlock.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.relayoutAllGroups()
        }
    }

    func relayoutAllGroups() {
        pruneDeadWindows()
        for group in groups {
            // macOS may have moved the active window (e.g. a display went away).
            if let active = group.activeWindow, !group.isMinimized,
               let frame = engine.frame(of: active) {
                group.contentFrame = frame
            }
            if isGroupOnActiveSpace(group) {
                applyLayout(for: group)
            } else {
                group.panel.hide()
            }
        }
        syncPanelZOrderWithFrontmostGroupSoon()
    }

    func observeApplicationChanges() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        let pid = app.processIdentifier
        for group in groups {
            for window in group.windows where window.pid == pid {
                remove(window.id, from: group, keepWindowObserved: false)
            }
        }
        focusTracker.applicationTerminated(pid)
    }

    func pruneDeadWindows() {
        for group in groups {
            for window in group.windows where !engine.isAlive(window) {
                remove(window.id, from: group, keepWindowObserved: false)
            }
        }
    }

    @objc func activeSpaceChanged() {
        pruneDeadWindows()
        for group in groups {
            if isGroupOnActiveSpace(group) {
                applyLayout(for: group)
            } else {
                group.panel.hide()
            }
        }
    }

    @objc func applicationDidActivate(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            trackActivation(app.processIdentifier)
        }
        pruneDeadWindows()
        syncPanelZOrderWithFrontmostGroupSoon()
    }

    @objc func applicationDidLaunch(_ notification: Notification) {
        guard autoAddNewWindowsToStack,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        observeAppForWindowCreation(app)
    }

    func isGroupOnActiveSpace(_ group: TabGroup) -> Bool {
        guard let groupSpace = group.spaceID,
              let activeSpace = engine.activeSpaceID() else {
            return true
        }
        return groupSpace == activeSpace
    }
}
