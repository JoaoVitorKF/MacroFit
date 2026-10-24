import Foundation
import Observation
import SwiftUI
import UIKit

/// Guarda a cor de destaque escolhida no Perfil (em `UserDefaults`, como "#7040C4") e a aplica no app.
/// É uma preferência do aparelho, não um dado de saúde: por isso não fica no SwiftData.
@Observable
final class ThemeStore {
    private(set) var theme: AccentTheme
    private let defaults: UserDefaults

    private static let lightKey = "theme.accentLight"
    private static let darkKey = "theme.accentDark"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AccentTheme(
            light: defaults.string(forKey: Self.lightKey).flatMap(RGBColor.init(hex:)) ?? AccentTheme.standard.light,
            dark: defaults.string(forKey: Self.darkKey).flatMap(RGBColor.init(hex:)) ?? AccentTheme.standard.dark
        )
    }

    /// Store do app. No modo demo usa um `UserDefaults` à parte, zerado a cada abertura,
    /// para prints e testes de interface não mexerem na cor real.
    static func makeForApp() -> ThemeStore {
        #if DEBUG
        if DemoData.isEnabled {
            let suite = "MacroFit.demo-theme"
            UserDefaults().removePersistentDomain(forName: suite)
            return ThemeStore(defaults: UserDefaults(suiteName: suite) ?? .standard)
        }
        #endif
        return ThemeStore()
    }

    func set(_ color: RGBColor, isDark: Bool) {
        if isDark {
            theme.dark = color
        } else {
            theme.light = color
        }
        save()
    }

    /// Volta ao roxo (claro) e amarelo (escuro).
    func reset() {
        theme = .standard
        defaults.removeObject(forKey: Self.lightKey)
        defaults.removeObject(forKey: Self.darkKey)
    }

    var isStandard: Bool { theme == .standard }

    private func save() {
        defaults.set(theme.light.hex, forKey: Self.lightKey)
        defaults.set(theme.dark.hex, forKey: Self.darkKey)
    }
}

// MARK: - Cores do SwiftUI

extension RGBColor {
    var uiColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension AccentTheme {
    /// Cor que muda sozinha entre o modo claro e o escuro.
    var accent: Color {
        let light = light.uiColor, dark = dark.uiColor
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    /// Texto e ícones **sobre** o destaque: branco ou preto, o mais legível em cada modo.
    var accentForeground: Color {
        let light = light.readableForeground.uiColor, dark = dark.readableForeground.uiColor
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
