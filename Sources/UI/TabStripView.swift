import SwiftUI

struct TabStripView: View {
    @ObservedObject var model: TabGroupViewModel
    @State private var hoveredID: WindowID?
    @State private var dragStartMouse: CGPoint?
    @State private var dragMode: DragMode?

    /// A strip drag either moves the whole group or reorders one tab.
    private enum DragMode {
        case move
        case reorder(WindowID)
    }

    var body: some View {
        GeometryReader { proxy in
            bar
                .contentShape(Rectangle())
                .onTapGesture { model.activateActive() }
                .gesture(dragGesture(stripWidth: proxy.size.width))
                .animation(.easeOut(duration: 0.18), value: isShowingPill)
        }
    }

    private var bar: some View {
        content.frame(height: Theme.stripHeight).glassBar()
    }

    private var isShowingPill: Bool { model.compact && !model.hovered }

    @ViewBuilder
    private var content: some View {
        if isShowingPill {
            compactPill.transition(.opacity)
        } else {
            fullBar.transition(.opacity)
        }
    }

    private var fullBar: some View {
        GeometryReader { proxy in
            let layout = tabLayout(forContainerWidth: proxy.size.width)
            if layout.overflowing {
                ScrollView(.horizontal, showsIndicators: false) {
                    tabRow(width: layout.width)
                }
            } else {
                tabRow(width: layout.width)
            }
        }
        .padding(Theme.stripPadding)
    }

    private func tabRow(width: CGFloat) -> some View {
        HStack(spacing: Theme.tabSpacing) {
            ForEach(model.tabs) { tab in
                TabItemView(
                    tab: tab,
                    isActive: tab.id == model.activeID,
                    isHovered: tab.id == hoveredID,
                    width: width,
                    mark: model.marks[tab.id],
                    onClose: { model.close(tab.id) }
                )
                .onHover { hoveredID = $0 ? tab.id : (hoveredID == tab.id ? nil : hoveredID) }
                .onTapGesture { model.select(tab.id) }
                .contextMenu {
                    Button("Remove from Group") { model.close(tab.id) }
                    Button("Close Window") { model.closeWindow(tab.id) }
                }
            }
        }
        .frame(height: Theme.tabHeight)
        .animation(.easeOut(duration: 0.15), value: model.tabs.map(\.id))
    }

    private var compactPill: some View {
        HStack(spacing: 4) {
            ForEach(model.tabs) { tab in
                compactIcon(for: tab)
            }
        }
        .padding(.horizontal, Theme.compactPillPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func compactIcon(for tab: TabDescriptor) -> some View {
        let isActive = tab.id == model.activeID
        Group {
            if let img = tab.appIcon() {
                Image(nsImage: img).resizable()
            } else {
                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.2))
            }
        }
        .frame(width: Theme.compactIconSize, height: Theme.compactIconSize)
        .opacity(isActive ? 1.0 : 0.45)
    }

    private func dragGesture(stripWidth: CGFloat) -> some Gesture {
        // The panel moves during a group move, so use screen coordinates for it.
        // Reordering keeps the panel still, so the panel-local x is enough.
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                if dragMode == nil {
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    if horizontal, let id = tabID(at: value.startLocation.x, stripWidth: stripWidth) {
                        dragMode = .reorder(id)
                    } else {
                        dragMode = .move
                        dragStartMouse = NSEvent.mouseLocation
                        model.moveBegan()
                    }
                }
                switch dragMode {
                case .reorder(let id):
                    if let index = slotIndex(at: value.location.x, stripWidth: stripWidth) {
                        model.reorder(id, to: index)
                    }
                case .move, nil:
                    let mouse = NSEvent.mouseLocation
                    let start = dragStartMouse ?? mouse
                    model.moveChanged(CGSize(width: mouse.x - start.x,
                                             height: mouse.y - start.y))
                }
            }
            .onEnded { _ in
                if case .move = dragMode { model.moveEnded() }
                dragMode = nil
                dragStartMouse = nil
            }
    }

    /// Tab slot under panel-local `x`. Nil for the compact pill or a
    /// scrolling strip, where slots don't map to positions.
    // ponytail: no reorder while the strip overflows and scrolls; add scroll-offset tracking if needed.
    private func slotIndex(at x: CGFloat, stripWidth: CGFloat) -> Int? {
        guard !isShowingPill, !model.tabs.isEmpty else { return nil }
        let layout = tabLayout(forContainerWidth: stripWidth - Theme.stripPadding * 2)
        guard !layout.overflowing else { return nil }
        let slot = Int((x - Theme.stripPadding) / (layout.width + Theme.tabSpacing))
        return min(max(slot, 0), model.tabs.count - 1)
    }

    private func tabID(at x: CGFloat, stripWidth: CGFloat) -> WindowID? {
        slotIndex(at: x, stripWidth: stripWidth).map { model.tabs[$0].id }
    }

    private func tabLayout(forContainerWidth containerWidth: CGFloat) -> (width: CGFloat, overflowing: Bool) {
        let count = CGFloat(max(model.tabs.count, 1))
        let totalSpacing = Theme.tabSpacing * (count - 1)
        let available = max(containerWidth - totalSpacing, 0)
        let ideal = available / count
        let overflowing = ideal < Theme.tabMinWidth
        return (overflowing ? Theme.tabMinWidth : ideal, overflowing)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

private extension View {
    func glassBar() -> some View { modifier(GlassBar()) }
}

/// Liquid Glass on macOS 26+, HUD material fallback otherwise; tinted to
/// match the strip's light or dark appearance.
private struct GlassBar: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.stripCornerRadius, style: .continuous)
        let dark = scheme == .dark
        if #available(macOS 26.0, *) {
            content
                .background(shape.fill(dark ? Color.black.opacity(0.45) : Color.white.opacity(0.35)))
                .glassEffect(.regular, in: shape)
        } else {
            content.background(
                ZStack {
                    VisualEffectBackground(material: dark ? .hudWindow : .menu, blending: .behindWindow)
                    shape.fill(dark ? Color.black.opacity(0.18) : Color.white.opacity(0.25))
                }
                .clipShape(shape)
                .overlay(shape.stroke(Color.primary.opacity(0.10), lineWidth: 1))
            )
        }
    }
}
