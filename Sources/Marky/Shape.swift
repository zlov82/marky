import AppKit

struct Shape {
    var tool: Tool
    var color: NSColor
    var width: CGFloat
    var start: CGPoint
    var end: CGPoint
    var trail: [CGPoint]      // только для свободной линии
    var constrained = false   // зажат ⇧

    init(tool: Tool, color: NSColor, width: CGFloat, at point: CGPoint) {
        self.tool = tool
        self.color = color
        self.width = width
        start = point
        end = point
        trail = [point]
    }

    mutating func extend(to point: CGPoint) {
        end = point
        if tool == .freehand { trail.append(point) }
    }

    /// Достаточно ли протянули мышь, чтобы это считалось фигурой, а не случайным кликом.
    var isMeaningful: Bool {
        hypot(end.x - start.x, end.y - start.y) > 2
    }

    /// Конец с учётом ⇧: для прямоугольника и окружности делает сторону равной.
    private var resolvedEnd: CGPoint {
        guard constrained, tool == .rectangle || tool == .circle else { return end }
        let dx = end.x - start.x, dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        return CGPoint(x: start.x + (dx < 0 ? -side : side),
                       y: start.y + (dy < 0 ? -side : side))
    }

    func draw() {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        switch tool {
        case .freehand:
            if constrained {
                path.move(to: start)
                path.line(to: end)
            } else if trail.count > 1 {
                path.move(to: trail[0])
                trail.dropFirst().forEach { path.line(to: $0) }
            }
        case .arrow:
            addArrow(to: path)
        case .rectangle:
            path.appendRect(boundingRect)
        case .circle:
            path.appendOval(in: boundingRect)
        }

        color.setStroke()
        path.stroke()
    }

    private var boundingRect: NSRect {
        let e = resolvedEnd
        return NSRect(x: min(start.x, e.x), y: min(start.y, e.y),
                      width: abs(e.x - start.x), height: abs(e.y - start.y))
    }

    private func addArrow(to path: NSBezierPath) {
        guard hypot(end.x - start.x, end.y - start.y) > 1 else { return }
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = max(14, width * 4)
        for side in [-1.0, 1.0] {
            let a = angle + side * .pi / 6
            path.move(to: end)
            path.line(to: CGPoint(x: end.x - head * cos(a), y: end.y - head * sin(a)))
        }
    }
}
