import AppKit
import Combine

/// Observable state and callbacks for a group's strip UI.
@MainActor
final class TabGroupViewModel: ObservableObject, Identifiable {
    let id = UUID()

    @Published var tabs: [TabDescriptor] = []
    @Published var activeID: WindowID?
    /// Mark letter per window, shown as a badge on the tab.
    @Published var marks: [WindowID: String] = [:]

    @Published var compact = false
    @Published var hovered = false

    var onSelect: ((WindowID) -> Void)?
    var onClose: ((WindowID) -> Void)?
    var onCloseWindow: ((WindowID) -> Void)?
    var onReorder: ((WindowID, Int) -> Void)?

    var onMoveBegan: (() -> Void)?
    var onMoveChanged: ((CGSize) -> Void)?
    var onMoveEnded: (() -> Void)?

    var onActivateActive: (() -> Void)?

    func select(_ id: WindowID) { onSelect?(id) }
    func close(_ id: WindowID) { onClose?(id) }
    func closeWindow(_ id: WindowID) { onCloseWindow?(id) }
    func reorder(_ id: WindowID, to index: Int) { onReorder?(id, index) }
    func activateActive() { onActivateActive?() }

    func moveBegan() { onMoveBegan?() }
    func moveChanged(_ translation: CGSize) { onMoveChanged?(translation) }
    func moveEnded() { onMoveEnded?() }
}
