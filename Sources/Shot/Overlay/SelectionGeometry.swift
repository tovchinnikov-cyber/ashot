import AppKit

struct SelectionGeometry {
    enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    var origin: NSPoint
    var size: NSSize

    var rect: NSRect {
        NSRect(origin: origin, size: size).standardized
    }

    var isEmpty: Bool {
        rect.width < 1 || rect.height < 1
    }

    func pixelRect(scaleFactor: CGFloat) -> CGRect {
        let r = rect
        return CGRect(
            x: r.origin.x * scaleFactor,
            y: r.origin.y * scaleFactor,
            width: r.width * scaleFactor,
            height: r.height * scaleFactor
        )
    }

    var sizeLabel: String {
        let r = rect
        return "\(Int(r.width)) × \(Int(r.height))"
    }

    private static let handleSize: CGFloat = 8

    func handleRects() -> [Handle: NSRect] {
        let r = rect
        let hs = Self.handleSize
        let half = hs / 2
        return [
            .topLeft:     NSRect(x: r.minX - half, y: r.maxY - half, width: hs, height: hs),
            .top:         NSRect(x: r.midX - half, y: r.maxY - half, width: hs, height: hs),
            .topRight:    NSRect(x: r.maxX - half, y: r.maxY - half, width: hs, height: hs),
            .right:       NSRect(x: r.maxX - half, y: r.midY - half, width: hs, height: hs),
            .bottomRight: NSRect(x: r.maxX - half, y: r.minY - half, width: hs, height: hs),
            .bottom:      NSRect(x: r.midX - half, y: r.minY - half, width: hs, height: hs),
            .bottomLeft:  NSRect(x: r.minX - half, y: r.minY - half, width: hs, height: hs),
            .left:        NSRect(x: r.minX - half, y: r.midY - half, width: hs, height: hs),
        ]
    }

    func hitTestHandle(at point: NSPoint) -> Handle? {
        let rects = handleRects()
        let inflated: CGFloat = 4
        for (handle, rect) in rects {
            if rect.insetBy(dx: -inflated, dy: -inflated).contains(point) {
                return handle
            }
        }
        return nil
    }

    func resized(handle: Handle, to point: NSPoint) -> SelectionGeometry {
        var r = rect
        switch handle {
        case .topLeft:
            r = NSRect(x: point.x, y: r.minY, width: r.maxX - point.x, height: point.y - r.minY)
        case .top:
            r = NSRect(x: r.minX, y: r.minY, width: r.width, height: point.y - r.minY)
        case .topRight:
            r = NSRect(x: r.minX, y: r.minY, width: point.x - r.minX, height: point.y - r.minY)
        case .right:
            r = NSRect(x: r.minX, y: r.minY, width: point.x - r.minX, height: r.height)
        case .bottomRight:
            r = NSRect(x: r.minX, y: point.y, width: point.x - r.minX, height: r.maxY - point.y)
        case .bottom:
            r = NSRect(x: r.minX, y: point.y, width: r.width, height: r.maxY - point.y)
        case .bottomLeft:
            r = NSRect(x: point.x, y: point.y, width: r.maxX - point.x, height: r.maxY - point.y)
        case .left:
            r = NSRect(x: point.x, y: r.minY, width: r.maxX - point.x, height: r.height)
        }
        let standardized = r.standardized
        return SelectionGeometry(origin: standardized.origin, size: standardized.size)
    }

    func moved(delta: NSPoint) -> SelectionGeometry {
        SelectionGeometry(
            origin: NSPoint(x: origin.x + delta.x, y: origin.y + delta.y),
            size: size
        )
    }

    func clamped(to bounds: NSRect) -> SelectionGeometry {
        var r = rect
        r.origin.x = max(bounds.minX, min(r.origin.x, bounds.maxX - r.width))
        r.origin.y = max(bounds.minY, min(r.origin.y, bounds.maxY - r.height))
        return SelectionGeometry(origin: r.origin, size: r.size)
    }

    static func cursorForHandle(_ handle: Handle) -> NSCursor {
        switch handle {
        case .topLeft, .bottomRight: return .crosshair
        case .topRight, .bottomLeft: return .crosshair
        case .top, .bottom: return .resizeUpDown
        case .left, .right: return .resizeLeftRight
        }
    }
}
