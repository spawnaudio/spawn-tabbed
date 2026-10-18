import CoreGraphics

/// Where to park an inactive tab: 1pt on its screen's bottom corner, so AX
/// does not clamp it, and never overlapping a neighbouring display.
enum ParkingSpot {
    /// - Parameters:
    ///   - screens: `(frame, visibleFrame)` per display, preferred screen first.
    static func frame(for size: CGSize, screens: [(frame: CGRect, visible: CGRect)]) -> CGRect? {
        for (index, screen) in screens.enumerated() {
            let y = screen.visible.minY + 1 - size.height
            let corners = [
                CGPoint(x: screen.visible.maxX - 1, y: y),             // bottom-right
                CGPoint(x: screen.visible.minX + 1 - size.width, y: y) // bottom-left
            ]
            for origin in corners {
                let parked = CGRect(origin: origin, size: size)
                let others = screens.enumerated().filter { $0.offset != index }
                if !others.contains(where: { $0.element.frame.intersects(parked) }) {
                    return parked
                }
            }
        }
        // Every corner touches another display; fall back to the old behaviour.
        return screens.first.map {
            CGRect(x: $0.visible.maxX - 1, y: $0.visible.minY + 1 - size.height,
                   width: size.width, height: size.height)
        }
    }
}
