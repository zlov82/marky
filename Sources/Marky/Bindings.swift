import AppKit
import Carbon.HIToolbox

enum Action: String, CaseIterable {
    case toggle, freehand, arrow, rectangle, circle, red, yellow, blue, green, thinner, thicker

    var title: String {
        switch self {
        case .toggle: "Включить / выключить рисование"
        case .freehand: "Свободная линия"
        case .arrow: "Стрелка"
        case .rectangle: "Прямоугольник"
        case .circle: "Окружность"
        case .red: "Красный"
        case .yellow: "Жёлтый"
        case .blue: "Синий"
        case .green: "Зелёный"
        case .thinner: "Тоньше"
        case .thicker: "Толще"
        }
    }

    var isGlobal: Bool { self == .toggle }
}

/// Физическая клавиша и модификаторы. Привязка к коду клавиши, а не к символу,
/// поэтому работает в любой раскладке.
struct KeyBinding: Codable, Equatable {
    var keyCode: Int
    var modifiers: UInt

    static let relevantFlags: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    init(keyCode: Int, modifiers: NSEvent.ModifierFlags = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.relevantFlags).rawValue
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: Int {
        var result = 0
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.shift) { result |= shiftKey }
        if flags.contains(.command) { result |= cmdKey }
        return result
    }

    var label: String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + (Self.keyNames[keyCode] ?? "Клавиша \(keyCode)")
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Пробел", 50: "`",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

extension Notification.Name {
    static let bindingsChanged = Notification.Name("MarkyBindingsChanged")
}

enum Bindings {
    static let defaults: [Action: KeyBinding] = [
        .toggle: KeyBinding(keyCode: kVK_ANSI_D, modifiers: [.control, .option]),
        .freehand: KeyBinding(keyCode: kVK_ANSI_F),
        .arrow: KeyBinding(keyCode: kVK_ANSI_A),
        .rectangle: KeyBinding(keyCode: kVK_ANSI_R),
        .circle: KeyBinding(keyCode: kVK_ANSI_C),
        .red: KeyBinding(keyCode: kVK_ANSI_1),
        .yellow: KeyBinding(keyCode: kVK_ANSI_2),
        .blue: KeyBinding(keyCode: kVK_ANSI_3),
        .green: KeyBinding(keyCode: kVK_ANSI_4),
        .thinner: KeyBinding(keyCode: kVK_ANSI_LeftBracket),
        .thicker: KeyBinding(keyCode: kVK_ANSI_RightBracket),
    ]

    private static let storageKey = "bindings"
    private(set) static var current: [Action: KeyBinding] = load()

    static func binding(for action: Action) -> KeyBinding {
        current[action] ?? defaults[action]!
    }

    /// Действие режима рисования по коду клавиши (глобальный хоткей сюда не входит).
    static func action(forKeyCode code: Int) -> Action? {
        Action.allCases.first { !$0.isGlobal && binding(for: $0).keyCode == code }
    }

    /// Текст ошибки, если назначение недопустимо, иначе nil.
    static func validate(_ candidate: KeyBinding, for action: Action) -> String? {
        if action.isGlobal {
            if candidate.flags.isDisjoint(with: [.control, .option, .command]) {
                return "Для глобального хоткея нужен хотя бы один модификатор: ⌃, ⌥ или ⌘."
            }
            return nil
        }
        if !candidate.flags.isEmpty {
            return "Для клавиш режима рисования модификаторы не нужны."
        }
        if candidate.keyCode == kVK_Escape || candidate.keyCode == kVK_Delete {
            return "Esc и ⌫ зарезервированы."
        }
        if let other = Action.allCases.first(where: {
            !$0.isGlobal && $0 != action && binding(for: $0).keyCode == candidate.keyCode
        }) {
            return "Эта клавиша уже назначена: «\(other.title)»."
        }
        return nil
    }

    static func set(_ binding: KeyBinding, for action: Action) {
        current[action] = binding
        save()
    }

    static func reset() {
        current = defaults
        save()
    }

    private static func save() {
        let stored = Dictionary(uniqueKeysWithValues: current.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        NotificationCenter.default.post(name: .bindingsChanged, object: nil)
    }

    private static func load() -> [Action: KeyBinding] {
        var result = defaults
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([String: KeyBinding].self, from: data)
        else { return result }
        for (name, binding) in stored {
            if let action = Action(rawValue: name) { result[action] = binding }
        }
        return result
    }
}
