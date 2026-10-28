import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let overlay = OverlayController()
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        overlay.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()

        registerHotKey()
        NotificationCenter.default.addObserver(forName: .bindingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.registerHotKey()
        }

        let settings = SettingsWindowController.shared
        // Пока записывается сочетание, хоткей снят, чтобы он не перехватывал нажатие.
        settings.onRecording = { [weak self] recording in
            if recording { self?.hotKey = nil } else { self?.registerHotKey() }
        }
        settings.canRegisterGlobal = { binding in
            HotKey(keyCode: binding.keyCode, modifiers: binding.carbonModifiers) {} != nil
        }
    }

    private func registerHotKey() {
        hotKey = nil // иначе повторная регистрация того же сочетания не пройдёт
        let binding = Bindings.binding(for: .toggle)
        hotKey = HotKey(keyCode: binding.keyCode, modifiers: binding.carbonModifiers) { [weak self] in
            self?.overlay.toggle()
        }
        if hotKey == nil {
            NSLog("Marky: не удалось зарегистрировать хоткей \(binding.label)")
        }
    }

    private func updateIcon() {
        let name = overlay.isActive ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Marky")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // MARK: Меню

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(title: overlay.isActive ? "Закончить рисование" : "Начать рисование",
                                action: #selector(toggleOverlay), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Горячие клавиши", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for line in Self.shortcutLines() {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Настройки…", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: "Запускать при входе в систему",
                               action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Выйти", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
    }

    private static func shortcutLines() -> [String] {
        var lines = Action.allCases.map { "\(Bindings.binding(for: $0).label) — \($0.title.lowercased())" }
        lines += [
            "⇧ — прямая линия, квадрат, круг",
            "⌘Z — отменить последнюю фигуру",
            "⌫ — очистить всё",
            "Esc — выйти",
        ]
        return lines
    }

    @objc private func toggleOverlay() {
        overlay.toggle()
    }

    @objc private func openSettings() {
        overlay.hide()
        SettingsWindowController.shared.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("Marky: автозапуск не переключился: \(error)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
