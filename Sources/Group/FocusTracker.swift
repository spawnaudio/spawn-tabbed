import AppKit

/// Owns the answer to "which group does the user mean?" — see ADR-0001.
///
/// The controller feeds events (push); reads are synchronous. Resolution:
/// the frontmost app's focused tab, else the visually frontmost group,
/// else the most recently focused group, else none.
@MainActor
final class FocusTracker {
    struct GroupSnapshot: Equatable {
        let id: UUID
        let activeWindowID: WindowID
        let pid: pid_t
    }

    private let groups: () -> [GroupSnapshot]
    private let zOrderedWindowIDs: () -> [WindowID]

    private var frontmostPID: pid_t?
    private var focusedWindowByPID: [pid_t: WindowID] = [:]
    private var recentGroupID: UUID?

    init(groups: @escaping () -> [GroupSnapshot],
         zOrderedWindowIDs: @escaping () -> [WindowID]) {
        self.groups = groups
        self.zOrderedWindowIDs = zOrderedWindowIDs
    }

    // MARK: - Events

    func applicationActivated(_ pid: pid_t) {
        frontmostPID = pid
    }

    func applicationTerminated(_ pid: pid_t) {
        focusedWindowByPID[pid] = nil
        if frontmostPID == pid {
            frontmostPID = nil
        }
    }

    func windowFocused(_ windowID: WindowID, in pid: pid_t) {
        focusedWindowByPID[pid] = windowID
        if let group = groups().first(where: { $0.activeWindowID == windowID }) {
            recentGroupID = group.id
        }
    }

    // MARK: - Read

    func focusedGroupID() -> UUID? {
        let candidates = groups()

        if let pid = frontmostPID,
           let focused = focusedWindowByPID[pid],
           let match = candidates.first(where: { $0.pid == pid && $0.activeWindowID == focused }) {
            return match.id
        }

        let frontmost = zOrderedWindowIDs().compactMap { id in
            candidates.first { $0.activeWindowID == id }
        }.first
        if let frontmost {
            return frontmost.id
        }

        if let recentGroupID, candidates.contains(where: { $0.id == recentGroupID }) {
            return recentGroupID
        }
        return nil
    }
}
