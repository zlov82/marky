import AppKit
import Carbon.HIToolbox

/// Кнопка-поле: нажать, затем нажать нужную комбинацию.
final class KeyRecorderButton: NSButton {
    let shortcutAction: Action
    var canRegisterGlobal: (KeyBinding) -> Bool = { _ in true }
    var onRecording: (Bool) -> Void = { _ in }
    var onMessage: (String?) -> Void = { _ in }
    private var isRecording = false

    init(action: Action) {
        shortcutAction = action
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        self.action = #selector(startRecording)
        widthAnchor.constraint(equalToConstant: 170).isActive = true
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var acceptsFirstResponder: Bool { true }

    func refresh() {
        title = isRecording ? "Нажмите сочетание…" : Bindings.binding(for: shortcutAction).label
    }

    @objc private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        onMessage(nil)
        onRecording(true)
        window?.makeFirstResponder(self)
        refresh()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        onRecording(false)
        refresh()
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    // Сочетания с ⌘ приходят сюда раньше keyDown.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        handle(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        handle(event)
    }

    private func handle(_ event: NSEvent) {
        defer { window?.makeFirstResponder(nil) }
        if Int(event.keyCode) == kVK_Escape { return }

        let candidate = KeyBinding(keyCode: Int(event.keyCode), modifiers: event.modifierFlags)
        if let problem = Bindings.validate(candidate, for: shortcutAction) {
            onMessage(problem)
        } else if shortcutAction.isGlobal, !canRegisterGlobal(candidate) {
            onMessage("Это сочетание занято системой или другим приложением.")
        } else {
            Bindings.set(candidate, for: shortcutAction)
        }
    }
}

final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()

    var canRegisterGlobal: (KeyBinding) -> Bool = { _ in true }
    var onRecording: (Bool) -> Void = { _ in }

    private var window: NSWindow?
    private var buttons: [KeyRecorderButton] = []
    private let messageLabel = NSTextField(labelWithString: "")

    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: .bindingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.buttons.forEach { $0.refresh() }
        }
    }

    func show() {
        if window == nil { buildWindow() }
        messageLabel.stringValue = ""
        buttons.forEach { $0.refresh() }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        stack.addArrangedSubview(sectionTitle("Глобальный хоткей"))
        stack.addArrangedSubview(row(for: .toggle))
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)

        stack.addArrangedSubview(sectionTitle("В режиме рисования"))
        for action in Action.allCases where !action.isGlobal {
            stack.addArrangedSubview(row(for: action))
        }

        let note = NSTextField(labelWithString: "Не настраиваются: Esc — выход, ⌘Z — отмена, ⌫ — очистить, ⇧ — ровные фигуры.")
        note.textColor = .secondaryLabelColor
        note.font = .systemFont(ofSize: 11)
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(note)

        messageLabel.textColor = .systemRed
        messageLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(messageLabel)

        let reset = NSButton(title: "Сбросить по умолчанию", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        stack.addArrangedSubview(reset)

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Настройки Marky"
        window.isReleasedWhenClosed = false
        window.contentView = stack
        window.setContentSize(stack.fittingSize)
        window.center()
        self.window = window
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private func row(for action: Action) -> NSStackView {
        let label = NSTextField(labelWithString: action.title)
        label.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let button = KeyRecorderButton(action: action)
        button.canRegisterGlobal = { [weak self] in self?.canRegisterGlobal($0) ?? true }
        button.onRecording = { [weak self] in self?.onRecording($0) }
        button.onMessage = { [weak self] in self?.messageLabel.stringValue = $0 ?? "" }
        buttons.append(button)

        let row = NSStackView(views: [label, button])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    @objc private func resetDefaults() {
        messageLabel.stringValue = ""
        Bindings.reset()
    }
}
