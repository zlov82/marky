import AppKit

enum Tool: String {
    case freehand, arrow, rectangle, circle
}

/// Красный (по умолчанию), жёлтый, синий, зелёный: клавиши 1–4.
let palette: [NSColor] = [
    NSColor(srgbRed: 0.93, green: 0.20, blue: 0.20, alpha: 1),
    NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1),
    NSColor(srgbRed: 0.10, green: 0.45, blue: 0.95, alpha: 1),
    NSColor(srgbRed: 0.15, green: 0.75, blue: 0.30, alpha: 1),
]

let widthRange = 1...20

/// Выбор инструмента, цвета и толщины переживает перезапуск.
enum Settings {
    private static let defaults = UserDefaults.standard

    static var tool: Tool {
        get { defaults.string(forKey: "tool").flatMap(Tool.init(rawValue:)) ?? .freehand }
        set { defaults.set(newValue.rawValue, forKey: "tool") }
    }

    static var colorIndex: Int {
        get {
            let value = defaults.object(forKey: "colorIndex") as? Int ?? 0
            return palette.indices.contains(value) ? value : 0
        }
        set { defaults.set(newValue, forKey: "colorIndex") }
    }

    static var width: Int {
        get {
            let value = defaults.object(forKey: "width") as? Int ?? 4
            return min(max(value, widthRange.lowerBound), widthRange.upperBound)
        }
        set { defaults.set(newValue, forKey: "width") }
    }
}
