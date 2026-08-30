import SwiftUI

// MARK: - Catppuccin palettes (Mocha dark, Latte light)

private func rgb(_ hex: UInt32) -> Color {
    Color(red: Double((hex >> 16) & 0xFF) / 255,
          green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255)
}

enum Mocha {
    static let base = rgb(0x1E1E2E), mantle = rgb(0x181825), crust = rgb(0x11111B)
    static let surface0 = rgb(0x313244), surface1 = rgb(0x45475A), surface2 = rgb(0x585B70)
    static let text = rgb(0xCDD6F4), subtext0 = rgb(0xA6ADC8), overlay0 = rgb(0x6C7086)
    static let blue = rgb(0x89B4FA), green = rgb(0xA6E3A1), red = rgb(0xF38BA8)
    static let yellow = rgb(0xF9E2AF), mauve = rgb(0xCBA6F7), peach = rgb(0xFAB387)
}

enum Latte {
    static let base = rgb(0xEFF1F5), mantle = rgb(0xE6E9EF), crust = rgb(0xDCE0E8)
    static let surface0 = rgb(0xCCD0DA), surface1 = rgb(0xBCC0CC), surface2 = rgb(0xACB0BE)
    static let text = rgb(0x4C4F69), subtext0 = rgb(0x6C6F85), overlay0 = rgb(0x9CA0B0)
    static let blue = rgb(0x1E66F5), green = rgb(0x40A02B), red = rgb(0xD20F39)
    static let yellow = rgb(0xDF8E1D), mauve = rgb(0x8839EF), peach = rgb(0xFE640B)
}

/// Resolves the active palette from system appearance.
enum Theme {
    static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static var base: Color { isDark ? Mocha.base : Latte.base }
    static var mantle: Color { isDark ? Mocha.mantle : Latte.mantle }
    static var crust: Color { isDark ? Mocha.crust : Latte.crust }
    static var surface0: Color { isDark ? Mocha.surface0 : Latte.surface0 }
    static var surface1: Color { isDark ? Mocha.surface1 : Latte.surface1 }
    static var surface2: Color { isDark ? Mocha.surface2 : Latte.surface2 }
    static var text: Color { isDark ? Mocha.text : Latte.text }
    static var subtext0: Color { isDark ? Mocha.subtext0 : Latte.subtext0 }
    static var overlay0: Color { isDark ? Mocha.overlay0 : Latte.overlay0 }
    static var blue: Color { isDark ? Mocha.blue : Latte.blue }
    static var green: Color { isDark ? Mocha.green : Latte.green }
    static var red: Color { isDark ? Mocha.red : Latte.red }
    static var yellow: Color { isDark ? Mocha.yellow : Latte.yellow }
    static var mauve: Color { isDark ? Mocha.mauve : Latte.mauve }
    static var peach: Color { isDark ? Mocha.peach : Latte.peach }
}
