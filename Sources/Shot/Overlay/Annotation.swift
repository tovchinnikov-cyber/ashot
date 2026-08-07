import AppKit

enum AnnotationTool {
    case arrow
    case rectangle
    case text
}

struct Annotation {
    let tool: AnnotationTool
    let startPoint: NSPoint
    let endPoint: NSPoint
    let color: NSColor = .systemRed
    let lineWidth: CGFloat = 2.5

    func createPath() -> CGPath {
        switch tool {
        case .arrow:
            return arrowPath()
        case .rectangle:
            return rectanglePath()
        case .text:
            return CGMutablePath()
        }
    }

    private func arrowPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)

        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = hypot(dx, dy)
        guard length > 5 else { return path }

        let headLength: CGFloat = min(16, length * 0.3)
        let headAngle: CGFloat = .pi / 6

        let angle = atan2(dy, dx)

        let left = CGPoint(
            x: endPoint.x - headLength * cos(angle - headAngle),
            y: endPoint.y - headLength * sin(angle - headAngle)
        )
        let right = CGPoint(
            x: endPoint.x - headLength * cos(angle + headAngle),
            y: endPoint.y - headLength * sin(angle + headAngle)
        )

        path.move(to: left)
        path.addLine(to: endPoint)
        path.addLine(to: right)

        return path
    }

    private func rectanglePath() -> CGPath {
        let rect = NSRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
        return CGPath(rect: rect, transform: nil)
    }
}
