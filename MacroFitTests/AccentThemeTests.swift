import XCTest
@testable import MacroFit

/// Cor de destaque escolhida no Perfil: RGB/hex, contraste e o que fica salvo.
final class AccentThemeTests: XCTestCase {

    func testHexRoundTrip() {
        let purple = RGBColor(red: 112, green: 64, blue: 196)
        XCTAssertEqual(purple.hex, "#7040C4")
        XCTAssertEqual(RGBColor(hex: "#7040C4"), purple)
        XCTAssertEqual(RGBColor(hex: "7040c4"), purple, "Sem # e minúsculo")
        XCTAssertEqual(RGBColor(hex: " #fc0 "), RGBColor(red: 255, green: 204, blue: 0), "Forma curta")
        XCTAssertEqual(RGBColor(hex: "##7040C4"), purple, "Colado num campo que já tinha #")
    }

    func testInvalidHex() {
        XCTAssertNil(RGBColor(hex: ""))
        XCTAssertNil(RGBColor(hex: "#12345"))
        XCTAssertNil(RGBColor(hex: "#GGGGGG"))
    }

    func testChannelsAreClamped() {
        let color = RGBColor(red: 300, green: -5, blue: 128)
        XCTAssertEqual(color, RGBColor(red: 255, green: 0, blue: 128))
    }

    func testContrastMatchesWCAG() {
        // Valores de referência da WCAG: preto × branco = 21:1
        XCTAssertEqual(RGBColor.black.contrast(with: .white), 21, accuracy: 0.01)
        XCTAssertEqual(RGBColor.white.contrast(with: .white), 1, accuracy: 0.01)
        // Os números do CLAUDE.md: branco sobre o roxo 6,5:1 e preto sobre o amarelo 13,9:1
        XCTAssertEqual(AccentTheme.standard.light.contrast(with: .white), 6.5, accuracy: 0.1)
        XCTAssertEqual(AccentTheme.standard.dark.contrast(with: .black), 13.9, accuracy: 0.1)
    }

    func testReadableForeground() {
        XCTAssertEqual(AccentTheme.standard.light.readableForeground, .white, "Branco sobre o roxo")
        XCTAssertEqual(AccentTheme.standard.dark.readableForeground, .black, "Preto sobre o amarelo")
        XCTAssertEqual(RGBColor(red: 52, green: 199, blue: 89).readableForeground, .black, "Preto sobre verde claro")
        XCTAssertEqual(RGBColor(red: 30, green: 120, blue: 50).readableForeground, .white, "Branco sobre verde escuro")
    }

    func testBackgroundContrastWarnsLightColorsInLightMode() {
        let yellowEverywhere = AccentTheme(light: AccentTheme.standard.dark, dark: AccentTheme.standard.dark)
        XCTAssertLessThan(yellowEverywhere.backgroundContrast(isDark: false), AccentTheme.minimumContrast, "Amarelo no fundo branco")
        XCTAssertGreaterThan(yellowEverywhere.backgroundContrast(isDark: true), AccentTheme.minimumContrast, "Amarelo no fundo escuro")
        XCTAssertGreaterThan(AccentTheme.standard.backgroundContrast(isDark: false), AccentTheme.minimumContrast)
    }

    func testStoreSavesAndResets() {
        let suite = "AccentThemeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = ThemeStore(defaults: defaults)
        XCTAssertEqual(store.theme, .standard, "Sem nada salvo, roxo e amarelo")
        XCTAssertTrue(store.isStandard)

        let green = RGBColor(red: 52, green: 199, blue: 89)
        store.set(green, isDark: false)
        XCTAssertEqual(store.theme.light, green)
        XCTAssertEqual(store.theme.dark, AccentTheme.standard.dark, "O modo escuro não muda")

        // Abrir de novo lê o que foi salvo
        XCTAssertEqual(ThemeStore(defaults: defaults).theme.light, green)

        store.reset()
        XCTAssertEqual(store.theme, .standard)
        XCTAssertEqual(ThemeStore(defaults: defaults).theme, .standard)
    }

    func testStoreIgnoresCorruptedValue() {
        let suite = "AccentThemeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("não é cor", forKey: "theme.accentLight")
        XCTAssertEqual(ThemeStore(defaults: defaults).theme.light, AccentTheme.standard.light)
    }
}
