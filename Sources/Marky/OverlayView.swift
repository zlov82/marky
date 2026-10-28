import AppKit
import Carbon.HIToolbox

final class OverlayView: NSView {
    var onExit: (() -> Void)?

    private var shapes: [Shape] = []
    private var current: Shape?
    private var tool = Settings.tool
    private var colorIndex = Settings.colorIndex
    private var width = Settings.width
    private var mouse: CGPoint = .zero

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.acceptsMouseMovedEvents = true
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self))
        mouse = convert(window.mouseLocationOutsideOfEventStream, from: nil)
    }

    // MARK: Отрисовка

    override func draw(_ dirtyRect: NSRect) {
        // Почти невидимая заливка: полностью прозрачные пиксели окно пропускает насквозь,
        // а режим рисования должен перехватывать клики.
        NSColor(white: 0, alpha: 0.01).setFill()
        dirtyRect.fill()

        shapes.forEach { $0.draw() }
        current?.draw()
        drawCursorPreview()
    }

    /// Кружок текущего цвета и толщины рядом с перекрестием.
    private func drawCursorPreview() {
        let diameter = CGFloat(width)
        let rect = NSRect(x: mouse.x + 16, y: mouse.y - 16 - diameter,
                          width: diameter, height: diameter)
        let dot = NSBezierPath(ovalIn: rect)
        palette[colorIndex].setFill()
        dot.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        dot.lineWidth = 1
        dot.stroke()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: Мышь

    override func mouseMoved(with event: NSEvent) {
        mouse = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouse = point
        var shape = Shape(tool: tool, color: palette[colorIndex], width: CGFloat(width), at: point)
        shape.constrained = event.modifierFlags.contains(.shift)
        current = shape
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouse = point
        current?.extend(to: point)
        current?.constrained = event.modifierFlags.contains(.shift)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let shape = current, shape.isMeaningful {
            shapes.append(shape)
        }
        current = nil
        needsDisplay = true
    }

    override func flagsChanged(with event: NSEvent) {
        current?.constrained = event.modifierFlags.contains(.shift)
        needsDisplay = true
    }

    // MARK: Клавиши (по кодам клавиш, чтобы работало в любой раскладке)

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, Int(event.keyCode) == kVK_ANSI_Z {
            undo()
            return true
        }
        return false
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty else { return }

        switch Int(event.keyCode) {
        case kVK_Escape: onExit?()
        case kVK_Delete: clear()
        case kVK_ANSI_F: select(.freehand)
        case kVK_ANSI_A: select(.arrow)
        case kVK_ANSI_R: select(.rectangle)
        case kVK_ANSI_C: select(.circle)
        case kVK_ANSI_1: select(color: 0)
        case kVK_ANSI_2: select(color: 1)
        case kVK_ANSI_3: select(color: 2)
        case kVK_ANSI_4: select(color: 3)
        case kVK_ANSI_LeftBracket: changeWidth(by: -1)
        case kVK_ANSI_RightBracket: changeWidth(by: 1)
        default: break
        }
    }

    // MARK: Действия

    private func select(_ newTool: Tool) {
        tool = newTool
        Settings.tool = newTool
    }

    private func select(color index: Int) {
        colorIndex = index
        Settings.colorIndex = index
        needsDisplay = true
    }

    private func changeWidth(by delta: Int) {
        width = min(max(width + delta, widthRange.lowerBound), widthRange.upperBound)
        Settings.width = width
        needsDisplay = true
    }

    private func undo() {
        guard current == nil, !shapes.isEmpty else { return }
        shapes.removeLast()
        needsDisplay = true
    }

    private func clear() {
        guard current == nil else { return }
        shapes.removeAll()
        needsDisplay = true
    }
}
