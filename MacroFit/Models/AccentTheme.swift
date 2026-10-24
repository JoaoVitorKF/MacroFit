import Foundation

/// Uma cor em RGB de 0 a 255, como na tabela de cores do Perfil.
struct RGBColor: Hashable {
    var red: Int
    var green: Int
    var blue: Int

    init(red: Int, green: Int, blue: Int) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    /// Lê "#7040C4", "7040c4" ou "#74C" (forma curta). `nil` se não for um hex válido.
    /// Ignora espaços e "#" repetidos (colar "#7040C4" num campo que já tinha "#").
    init?(hex: String) {
        var digits = hex.filter { $0 != "#" && !$0.isWhitespace }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(red: (value >> 16) & 0xFF, green: (value >> 8) & 0xFF, blue: value & 0xFF)
    }

    /// "#7040C4".
    var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    static func clamp(_ value: Int) -> Int { min(max(value, 0), 255) }

    static let white = RGBColor(red: 255, green: 255, blue: 255)
    static let black = RGBColor(red: 0, green: 0, blue: 0)

    // MARK: - Contraste (WCAG 2)

    /// Luminância relativa (0 = preto, 1 = branco).
    var luminance: Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// Contraste entre duas cores, de 1:1 (iguais) a 21:1 (preto e branco).
    func contrast(with other: RGBColor) -> Double {
        let (lighter, darker) = luminance > other.luminance ? (luminance, other.luminance) : (other.luminance, luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Branco ou preto, o que for mais legível sobre esta cor (texto dos botões cheios).
    var readableForeground: RGBColor {
        contrast(with: .white) >= contrast(with: .black) ? .white : .black
    }
}

/// Cor de destaque do app, uma para o modo claro e outra para o escuro.
struct AccentTheme: Hashable {
    var light: RGBColor
    var dark: RGBColor

    /// Roxo no claro e amarelo no escuro (o padrão escolhido pelo usuário).
    static let standard = AccentTheme(
        light: RGBColor(red: 112, green: 64, blue: 196),
        dark: RGBColor(red: 255, green: 204, blue: 0)
    )

    /// Fundo dos cards em cada modo (`secondarySystemGroupedBackground`), para avaliar o contraste.
    static let lightBackground = RGBColor.white
    static let darkBackground = RGBColor(red: 28, green: 28, blue: 30)

    /// Abaixo disso, ícones e textos no destaque ficam difíceis de ver sobre o fundo (WCAG para elementos gráficos).
    static let minimumContrast = 3.0

    /// Cores prontas para escolher com um toque.
    static let presets: [(name: String, color: RGBColor)] = [
        ("Roxo", RGBColor(red: 112, green: 64, blue: 196)),
        ("Amarelo", RGBColor(red: 255, green: 204, blue: 0)),
        ("Verde", RGBColor(red: 52, green: 199, blue: 89)),
        ("Verde escuro", RGBColor(red: 30, green: 120, blue: 50)),
        ("Azul", RGBColor(red: 0, green: 122, blue: 255)),
        ("Índigo", RGBColor(red: 88, green: 86, blue: 214)),
        ("Turquesa", RGBColor(red: 48, green: 176, blue: 199)),
        ("Rosa", RGBColor(red: 255, green: 45, blue: 85)),
        ("Laranja", RGBColor(red: 255, green: 149, blue: 0)),
        ("Grafite", RGBColor(red: 72, green: 72, blue: 74)),
    ]

    func color(isDark: Bool) -> RGBColor { isDark ? dark : light }

    /// Contraste do destaque com o fundo dos cards no modo indicado.
    func backgroundContrast(isDark: Bool) -> Double {
        color(isDark: isDark).contrast(with: isDark ? Self.darkBackground : Self.lightBackground)
    }
}
