import AppKit
import SwiftUI

/// Borderless non-activating panel for one group's tab strip.
final class TabBarPanel: NSPanel {
    let model: TabGroupViewModel

    private var isCompact = false
    private var restingFrame: CGRect = .zero
    private var expandedFrame: CGRect = .zero

    /// Grace margin around the expanded bar before compact mode collapses.
    private let collapseSafeZoneX: CGFloat = 28
    private let collapseSafeZoneY: CGFloat = 72
    private var collapseWatcher: Timer?

    /// AppKit hover tracking for the non-activating panel.
    private let trackingContainer: HoverTrackingView

    init(model: TabGroupViewModel) {
        self.model = model
        self.trackingContainer = HoverTrackingView()
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: Theme.stripHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = false
        level = .normal
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]

        let host = NSHostingView(rootView: TabStripView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        trackingContainer.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: trackingContainer.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: trackingContainer.trailingAnchor),
            host.topAnchor.constraint(equalTo: trackingContainer.topAnchor),
            host.bottomAnchor.constraint(equalTo: trackingContainer.bottomAnchor)
        ])
        contentView = trackingContainer

        trackingContainer.onHoverChange = { [weak self] hovering in
            self?.handleHover(hovering)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func place(at frame: CGRect) {
        setFrame(frame, display: true)
    }

    /// Apply a z-order decision from `PanelZOrderPolicy`.
    func apply(_ placement: PanelZOrder) {
        switch placement {
        case .float:
            level = .floating
            orderFront(nil)
        case .aboveActive(let id):
            level = .normal
            order(.above, relativeTo: Int(id))
        case .belowFrontmost(let id):
            level = .normal
            order(.below, relativeTo: Int(id))
        case .hide:
            level = .normal
            orderOut(nil)
        }
    }

    /// Configure resting and expanded frames for the current layout.
    func applyLayout(compact: Bool, resting: CGRect, expanded: CGRect) {
        isCompact = compact
        restingFrame = resting
        expandedFrame = expanded
        if !compact { cancelCollapseWatch() }
        let target = (compact && model.hovered) ? expanded : resting
        setFrame(target, display: true)
    }

    private func handleHover(_ hovering: Bool) {
        guard isCompact else { return }
        if hovering {
            cancelCollapseWatch()
            setExpanded(true)
        } else {
            beginCollapseWatch()
        }
    }

    private func setExpanded(_ expanded: Bool) {
        model.hovered = expanded
        let target = expanded ? expandedFrame : restingFrame
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            animator().setFrame(target, display: true)
        }
    }

    private func beginCollapseWatch() {
        cancelCollapseWatch()
        collapseWatcher = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickCollapseWatch() }
        }
    }

    private func tickCollapseWatch() {
        let safe = expandedFrame.insetBy(dx: -collapseSafeZoneX, dy: -collapseSafeZoneY)
        if !safe.contains(NSEvent.mouseLocation) {
            cancelCollapseWatch()
            setExpanded(false)
        }
    }

    private func cancelCollapseWatch() {
        collapseWatcher?.invalidate()
        collapseWatcher = nil
    }

    /// `nil` appearance follows the system; SwiftUI inherits it.
    var theme: StripTheme = .system {
        didSet {
            switch theme {
            case .system: appearance = nil
            case .dark: appearance = NSAppearance(named: .darkAqua)
            case .light: appearance = NSAppearance(named: .aqua)
            }
        }
    }

    func show() {
        if !isVisible {
            orderFront(nil)
        }
    }

    func hide() {
        cancelCollapseWatch()
        orderOut(nil)
    }
}

/// NSView-backed hover reporting for non-activating panels.
final class HoverTrackingView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}
