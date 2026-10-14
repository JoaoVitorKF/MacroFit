import XCTest

/// Testes de interface da aba Hoje (modo demo: meta 2.345 kcal, 1.330 kcal já consumidas).
final class TodayUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo"]
        app.launch()
    }

    private func fillMeal(name: String, kcal: String) {
        let manual = app.segmentedControls["modo-entrada"].buttons["Digitar valores"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        let nameField = app.textFields["campo-nome"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        for (identifier, value) in [("campo-calories", kcal), ("campo-protein", "20"), ("campo-carbs", "30"), ("campo-fat", "10")] {
            let field = app.textFields[identifier]
            field.tap()
            field.typeText(value)
            app.toolbars.buttons["OK"].tap()
        }
        app.buttons["Salvar"].tap()
    }

    func testRingShowsRemainingCalories() {
        // 2.345 − 1.330 = 1.015
        XCTAssertTrue(app.staticTexts["1.015"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["kcal restantes"].exists)
        XCTAssertTrue(app.staticTexts["57%"].exists)
    }

    func testBigAddButtonUpdatesRing() {
        let add = app.buttons["Adicionar refeição"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        fillMeal(name: "Wrap de frango", kcal: "300")

        // 1.015 − 300 = 715
        XCTAssertTrue(app.staticTexts["715"].waitForExistence(timeout: 5))
    }

    func testMealTypeRowOpensFormWithThatType() {
        // O demo não tem jantar hoje; tocar na linha "Jantar" abre o formulário já com esse tipo
        let dinnerRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Jantar")).firstMatch
        XCTAssertTrue(dinnerRow.waitForExistence(timeout: 5))
        dinnerRow.tap()
        fillMeal(name: "Sopa de legumes", kcal: "250")

        // Na aba Refeições, a nova refeição aparece no grupo Jantar
        app.tabBars.buttons["Refeições"].tap()
        XCTAssertTrue(app.staticTexts["Jantar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sopa de legumes")).firstMatch.exists)
    }
}
