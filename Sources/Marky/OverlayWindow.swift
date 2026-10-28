import AppKit

/// Безрамочное окно должно явно разрешить становиться key, иначе не получит клавиши.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Одно прозрачное окно на экране, где сейчас курсор.
final class OverlayController {
    private var window: OverlayWindow?

    var isActive: Bool { window != nil }
    var onChange: (() -> Void)?

    func show() {
        guard window == nil else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onExit = { [weak self] in self?.hide() }
        window.contentView = view

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        window.invalidateCursorRects(for: view)
        onChange?()
    }

    func hide() {
        guard let window else { return }
        window.orderOut(nil)
        self.window = nil
        onChange?()
    }

    func toggle() {
        isActive ? hide() : show()
    }
}
