import XCTest

/// Testes de interface do registro rápido (modo demo: 1.330 kcal hoje, meta 2.345 → faltam 1.015).
final class QuickAddUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo"]
        app.launch()
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var yogurtChip: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Adicionar Iogurte com whey")).firstMatch
    }

    func testQuickAddAndUndo() {
        XCTAssertTrue(app.staticTexts["1.015"].waitForExistence(timeout: 5))
        XCTAssertTrue(yogurtChip.waitForExistence(timeout: 5), "A refeição mais frequente do demo aparece nos atalhos")

        yogurtChip.tap()

        // Adicionou: 1.015 − 260 = 755, e o aviso com Desfazer aparece
        XCTAssertTrue(app.staticTexts["755"].waitForExistence(timeout: 3))
        let undo = app.buttons["Desfazer"]
        XCTAssertTrue(undo.exists)
        keepScreenshot("aviso-desfazer")

        undo.tap()
        XCTAssertTrue(app.staticTexts["1.015"].waitForExistence(timeout: 3), "Desfazer volta ao total anterior")
        XCTAssertFalse(app.buttons["Desfazer"].exists)
    }

    func testToastDisappearsByItself() {
        XCTAssertTrue(yogurtChip.waitForExistence(timeout: 5))
        yogurtChip.tap()
        XCTAssertTrue(app.buttons["Desfazer"].waitForExistence(timeout: 2))

        // Some depois de ~4 s e a refeição continua adicionada
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["Desfazer"])
        waitForExpectations(timeout: 7)
        XCTAssertTrue(app.staticTexts["755"].exists)
    }

    func testLongPressAddsDoublePortion() {
        XCTAssertTrue(yogurtChip.waitForExistence(timeout: 5))
        yogurtChip.press(forDuration: 1.0)

        // Menu de porção: 2 porções = 520 kcal
        let double = app.buttons["Adicionar 2 porções (520 kcal)"]
        XCTAssertTrue(double.waitForExistence(timeout: 3))
        keepScreenshot("menu-porcao")
        double.tap()

        // 1.015 − 520 = 495
        XCTAssertTrue(app.staticTexts["495"].waitForExistence(timeout: 3))
    }

    func testPortionPickerWhenRepeating() {
        app.buttons["Adicionar refeição"].firstMatch.tap()
        app.buttons["Repetir refeição anterior"].tap()
        let template = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Frango grelhado")).firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

        // Meia porção: 650 → 325 kcal, 52 → 26 g de proteína
        let picker = app.segmentedControls["seletor-porcao"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.buttons["½×"].tap()
        XCTAssertEqual(app.textFields["campo-calories"].value as? String, "325")
        XCTAssertEqual(app.textFields["campo-protein"].value as? String, "26")
        keepScreenshot("seletor-porcao")

        app.buttons["Salvar"].tap()
        // 1.015 − 325 = 690
        XCTAssertTrue(app.staticTexts["690"].waitForExistence(timeout: 5))
    }
}
