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

        hotKey = HotKey(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey) { [weak self] in
            self?.overlay.toggle()
        }
        if hotKey == nil {
            NSLog("Marky: не удалось зарегистрировать хоткей ⌃⌥D")
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
        for line in Self.shortcutLines {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            menu.addItem(item)
        }
        menu.addItem(.separator())

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

    private static let shortcutLines = [
        "⌃⌥D — включить / выключить рисование",
        "F — свободная линия",
        "A — стрелка",
        "R — прямоугольник",
        "C — окружность",
        "1 / 2 / 3 / 4 — красный / жёлтый / синий / зелёный",
        "[ / ] — тоньше / толще",
        "⇧ — прямая линия, квадрат, круг",
        "⌘Z — отменить последнюю фигуру",
        "⌫ — очистить всё",
        "Esc — выйти",
    ]

    @objc private func toggleOverlay() {
        overlay.toggle()
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
