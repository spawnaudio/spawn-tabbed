import Foundation

/// Saved groups and marks, so they survive a Tabbed restart.
///
/// Windows are keyed by window-server id + pid, which stay valid while the
/// owning app keeps running. A window whose app was relaunched has a new id
/// and is skipped on restore.
// ponytail: id-based matching only; add title/app matching if groups should survive app relaunches.
struct GroupStore {
    struct WindowRef: Codable, Equatable {
        let id: WindowID
        let pid: pid_t
    }

    struct SavedGroup: Codable, Equatable {
        let windows: [WindowRef]
        let activeIndex: Int
        let frame: CGRect
    }

    var defaults: UserDefaults = .standard
    private let groupsKey = "savedGroups"
    private let marksKey = "savedMarks"

    func loadGroups() -> [SavedGroup] {
        guard let data = defaults.data(forKey: groupsKey) else { return [] }
        return (try? JSONDecoder().decode([SavedGroup].self, from: data)) ?? []
    }

    func saveGroups(_ groups: [SavedGroup]) {
        defaults.set(try? JSONEncoder().encode(groups), forKey: groupsKey)
    }

    func loadMarks() -> [String: WindowRef] {
        guard let data = defaults.data(forKey: marksKey) else { return [:] }
        return (try? JSONDecoder().decode([String: WindowRef].self, from: data)) ?? [:]
    }

    func saveMarks(_ marks: [String: WindowRef]) {
        defaults.set(try? JSONEncoder().encode(marks), forKey: marksKey)
    }
}
