import AppKit
import ApplicationServices

extension TabGroupController {
    func observeWindows(in group: TabGroup) {
        for window in group.windows {
            observer.observe(window)
        }
    }

    func handleWindowNotification(id: WindowID, notification: String) {
        guard !isApplyingLayout, let group = group(containing: id) else { return }

        switch notification {
        case kAXUIElementDestroyedNotification:
            remove(id, from: group, keepWindowObserved: false)

        case kAXWindowMiniaturizedNotification:
            // Minimising the active tab minimises the whole group (upstream #4).
            if group.activeWindow?.id == id {
                group.isMinimized = true
                group.panel.hide()
            } else {
                remove(id, from: group, keepWindowObserved: false)
            }

        case kAXWindowDeminiaturizedNotification:
            guard group.activeWindow?.id == id, group.isMinimized else { return }
            group.isMinimized = false
            applyLayout(for: group)

        case kAXTitleChangedNotification:
            if let window = group.windows.first(where: { $0.id == id }) {
                _ = engine.refreshTitle(window)
                group.syncViewModel()
            }

        case kAXMovedNotification, kAXResizedNotification:
            guard group.activeWindow?.id == id,
                  !group.isMinimized,
                  id != draggedWindow?.id,
                  isGroupOnActiveSpace(group),
                  let frame = engine.frame(of: group.windows[group.activeIndex]) else {
                return
            }
            group.contentFrame = frame
            positionPanel(for: group)
            beginTrackingActiveMove(for: group)

        default:
            break
        }
    }

    func beginTrackingActiveMove(for group: TabGroup) {
        activeMoveGroup = group
        activeMoveDeadline = Date().addingTimeInterval(0.2)
        guard activeMoveTimer == nil else { return }
        activeMoveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickActiveMove() }
        }
    }

    func tickActiveMove() {
        guard let group = activeMoveGroup, let active = group.activeWindow,
              active.id != draggedWindow?.id, Date() <= activeMoveDeadline,
              let frame = engine.windowServerFrame(of: active.id) ?? engine.frame(of: active) else {
            endTrackingActiveMove()
            return
        }
        group.contentFrame = frame
        positionPanel(for: group)
    }

    func endTrackingActiveMove() {
        activeMoveTimer?.invalidate()
        activeMoveTimer = nil
        activeMoveGroup = nil
    }
}
