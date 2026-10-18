import AppKit

/// rcmd-style marks (upstream #3): tag any window with a letter, jump back to it.
extension TabGroupController {
    func keyboardShortcutAssignMark(_ letter: String) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ownPID,
              let id = engine.focusedOrMainWindowID(for: app.processIdentifier) else {
            return false
        }
        assignMark(letter, to: .init(id: id, pid: app.processIdentifier))
        return true
    }

    func keyboardShortcutJumpToMark(_ letter: String) -> Bool {
        guard let ref = marks[letter] else { return false }
        if let group = group(containing: ref.id) {
            selectTab(ref.id, in: group)
            return true
        }
        guard let window = engine.managedWindow(id: ref.id, pid: ref.pid) else {
            // The window is gone; free the letter and let the key through.
            marks[letter] = nil
            marksChanged()
            return false
        }
        engine.activate(window)
        return true
    }

    /// One letter per window: re-tagging a window moves its mark.
    func assignMark(_ letter: String, to ref: GroupStore.WindowRef) {
        marks = marks.filter { $0.value.id != ref.id }
        marks[letter] = ref
        marksChanged()
    }

    func marksChanged() {
        store.saveMarks(marks)
        let byWindow = Dictionary(marks.map { ($0.value.id, $0.key) }, uniquingKeysWith: { a, _ in a })
        for group in groups {
            group.viewModel.marks = byWindow
        }
    }
}
