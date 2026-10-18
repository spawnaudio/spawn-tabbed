import SwiftUI

struct TabItemView: View {
    let tab: TabDescriptor
    let isActive: Bool
    let isHovered: Bool
    let width: CGFloat
    var mark: String?
    let onClose: () -> Void

    @State private var closeHovered = false

    var body: some View {
        ZStack {
            HStack(spacing: 6) {
                icon

                Text(tab.title.isEmpty ? tab.appName : tab.title)
                    .font(.system(size: Theme.titleSize, weight: isActive ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Color.primary.opacity(textOpacity))

                if let mark {
                    Text(mark.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.15)))
                        .help("Jump here with the marks shortcut + \(mark.uppercased())")
                }
            }
            .padding(.horizontal, 22)

            if isHovered {
                HStack {
                    closeButton
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
            }
        }
        .frame(width: width, height: Theme.tabHeight)
        .pillHighlight(isActive: isActive, isHovered: isHovered)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        if let img = tab.appIcon() {
            Image(nsImage: img)
                .resizable()
                .frame(width: Theme.iconSize, height: Theme.iconSize)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.2))
                .frame(width: Theme.iconSize, height: Theme.iconSize)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.primary.opacity(closeHovered ? 0.95 : 0.6))
                .frame(width: 15, height: 15)
                .background(
                    Circle().fill(Color.primary.opacity(closeHovered ? 0.18 : 0.0))
                )
        }
        .buttonStyle(.plain)
        .help("Remove from Group")
        .onHover { closeHovered = $0 }
    }

    private var textOpacity: Double {
        if isActive { return Theme.textActive }
        if isHovered { return Theme.textHover }
        return Theme.textIdle
    }
}

private extension View {
    func pillHighlight(isActive: Bool, isHovered: Bool) -> some View {
        let shape = Capsule(style: .continuous)
        let fill = isActive ? Theme.fillActive : (isHovered ? Theme.fillHover : Theme.fillIdle)
        return self
            .background(shape.fill(Color.primary.opacity(fill)))
            .overlay(shape.stroke(Color.primary.opacity(isActive ? Theme.strokeActive : Theme.strokeIdle),
                                  lineWidth: 1))
    }
}
