import XCTest

/// Comemoração e dica do dia (modo demo: 115 de 160 g de proteína, 1.330 de 2.345 kcal).
final class CelebrationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["1.015"].waitForExistence(timeout: 5))
        sleep(1) // o observador de metas ignora o carregamento inicial
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCrossingProteinGoalCelebrates() {
        // Frango grelhado: +52 g → 167 g, passa dos 160 g
        let chip = app.buttons["atalho-Frango grelhado, arroz e feijão"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()

        let banner = app.buttons["comemoracao"]
        XCTAssertTrue(banner.waitForExistence(timeout: 3))
        XCTAssertTrue(banner.label.contains("Meta de proteína batida!"))
        keepScreenshot("comemoracao")

        // Toque fecha
        banner.tap()
        XCTAssertFalse(banner.waitForExistence(timeout: 1.5))
    }

    func testNoCelebrationWithoutCrossing() {
        // Ovos mexidos (+28 g → 143 g) não chega aos 160 g
        let chip = app.buttons["atalho-Ovos mexidos com pão integral"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()
        XCTAssertFalse(app.buttons["comemoracao"].waitForExistence(timeout: 2))
    }

    func testTipSuggestsAndAddsMeal() {
        let tipAdd = app.buttons["dica-adicionar"]
        XCTAssertTrue(tipAdd.waitForExistence(timeout: 5), "Faltam 45 g: a dica sugere algo do histórico")
        XCTAssertTrue(tipAdd.label.contains("Iogurte com whey"), "Melhor proteína por caloria que cabe no que falta")
        keepScreenshot("dica")

        tipAdd.tap()
        // 1.015 − 260 = 755, com o aviso de Desfazer
        XCTAssertTrue(app.staticTexts["755"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Desfazer"].exists)
    }
}
