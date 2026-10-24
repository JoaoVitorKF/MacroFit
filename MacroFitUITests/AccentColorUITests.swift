import XCTest

/// Perfil → Cor de destaque (modo demo: as cores ficam num UserDefaults à parte, zerado a cada abertura).
final class AccentColorUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo", "-demo-tab", "2"]
        app.launch()
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openColors() {
        let row = app.buttons["cor-destaque"]
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        row.tap()
        XCTAssertTrue(app.segmentedControls["modo-cor"].waitForExistence(timeout: 5))
        // Os testes rodam no modo claro do simulador: edita a cor do modo claro
        app.segmentedControls["modo-cor"].buttons["Modo claro"].tap()
    }

    func testPresetAndRGBTable() {
        openColors()
        let hex = app.textFields["campo-hex"]
        let red = app.textFields["valor-R"]
        for _ in 0..<3 where !hex.isHittable { app.swipeUp() }
        XCTAssertEqual(hex.value as? String, "#7040C4", "Começa no roxo")

        // Cor pronta: a tabela mostra os números dela
        for _ in 0..<3 where !app.buttons["cor-Verde escuro"].isHittable { app.swipeDown() }
        app.buttons["cor-Verde escuro"].tap()
        for _ in 0..<3 where !hex.isHittable { app.swipeUp() }
        XCTAssertEqual(red.value as? String, "30")
        XCTAssertEqual(app.textFields["valor-G"].value as? String, "120")
        XCTAssertEqual(hex.value as? String, "#1E7832")

        // Digitar na tabela: R = 200 → hex acompanha
        red.doubleTap()
        red.typeText("200")
        app.buttons["OK"].firstMatch.tap()
        XCTAssertTrue(app.textFields["campo-hex"].waitForExistence(timeout: 2))
        XCTAssertEqual(hex.value as? String, "#C87832")

        // Hex digitado muda a tabela
        hex.doubleTap()
        hex.typeText("#0A84FF\n")
        XCTAssertEqual(red.value as? String, "10")
        XCTAssertEqual(app.textFields["valor-B"].value as? String, "255")
        keepScreenshot("tabela-rgb")
    }

    func testLowContrastWarningAndReset() {
        openColors()
        // Amarelo no modo claro: pouco contraste com o fundo branco
        app.buttons["cor-Amarelo"].tap()
        let warning = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Pouco contraste")).firstMatch
        for _ in 0..<3 where !warning.exists { app.swipeUp() }
        XCTAssertTrue(warning.exists, "Avisa que amarelo no fundo branco fica difícil de ver")

        let reset = app.buttons["restaurar-cores"]
        for _ in 0..<3 where !reset.isHittable { app.swipeUp() }
        XCTAssertTrue(reset.isEnabled)
        reset.tap()
        XCTAssertFalse(reset.isEnabled, "Já está no padrão")
        XCTAssertEqual(app.textFields["campo-hex"].value as? String, "#7040C4")
    }

    func testNewColorReachesOtherTabsAndSheets() {
        openColors()
        app.buttons["cor-Verde escuro"].tap()

        // A cor vale na hora no resto do app, inclusive nas folhas (sheets)
        app.tabBars.buttons["Hoje"].tap()
        let field = app.textFields["campo-o-que-comer"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        keepScreenshot("hoje-verde")
        field.tap()
        field.typeText("arroz e frango\n")
        XCTAssertTrue(app.buttons["registrar-plano"].waitForExistence(timeout: 5))
        keepScreenshot("o-que-vou-comer-verde")
    }
}
