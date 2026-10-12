import XCTest

/// Testes de interface dos fluxos principais. Usam o modo demo (banco em memória),
/// então não dependem nem alteram dados reais.
final class MealsFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Idioma fixo para os textos e números (vírgula decimal, "1.330")
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
    }

    // MARK: - Helpers

    private func launch(_ arguments: String...) {
        app.launchArguments += arguments
        app.launch()
    }

    /// Botão cujo rótulo começa com o texto (as linhas de refeição combinam nome + macros + kcal).
    private func button(startingWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    private func type(_ text: String, into identifier: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Campo \(identifier) não encontrado")
        field.tap()
        field.typeText(text)
        closeKeyboard()
    }

    /// Toca no "OK" acima do teclado numérico (o teclado cobre os campos de baixo do formulário).
    private func closeKeyboard() {
        let ok = app.toolbars.buttons["OK"]
        if ok.exists { ok.tap() }
    }

    /// Apaga o conteúdo do campo e digita um novo valor.
    private func replace(_ identifier: String, with text: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Toca no fim do campo para o cursor ficar depois do texto
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
        closeKeyboard()
    }

    // MARK: - Onboarding

    func testOnboardingCreatesProfile() {
        launch("-demo-onboarding")

        let start = app.buttons["Começar"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled, "Sem dados, não dá para começar")

        type("30", into: "campo-age")
        type("80", into: "campo-weight")
        type("180", into: "campo-height")
        XCTAssertTrue(start.isEnabled)

        start.tap()

        // Saiu do onboarding e chegou às abas; no Perfil aparece a meta calculada (2.345 kcal)
        let profileTab = app.tabBars.buttons["Perfil"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        XCTAssertTrue(app.staticTexts["2.345"].waitForExistence(timeout: 5))
    }

    func testOnboardingRejectsAbsurdValues() {
        launch("-demo-onboarding")
        type("30", into: "campo-age")
        type("800", into: "campo-weight")
        type("180", into: "campo-height")

        XCTAssertFalse(app.buttons["Começar"].isEnabled)
        XCTAssertTrue(app.staticTexts["Peso deve estar entre 30 e 300 kg."].exists)
    }

    // MARK: - Refeições

    func testDayNavigationDoesNotTriggerOtherButtons() {
        launch("-demo", "-demo-tab", "1")

        XCTAssertTrue(button(startingWith: "Ovos mexidos").waitForExistence(timeout: 5))

        app.buttons["Dia anterior"].tap()

        // Foi para ontem e mostra as refeições de ontem...
        XCTAssertTrue(button(startingWith: "Ontem").waitForExistence(timeout: 3))
        XCTAssertTrue(button(startingWith: "Omelete de queijo").exists)
        XCTAssertFalse(button(startingWith: "Ovos mexidos").exists)
        // ...sem abrir o calendário nem pular de volta (bug de vários botões numa linha de List)
        XCTAssertFalse(app.navigationBars["Escolher dia"].exists)

        app.buttons["Voltar para hoje"].tap()
        XCTAssertTrue(button(startingWith: "Hoje").waitForExistence(timeout: 3))
        XCTAssertTrue(button(startingWith: "Ovos mexidos").exists)
    }

    func testAddMeal() {
        launch("-demo", "-demo-tab", "1")

        app.buttons["Adicionar refeição"].firstMatch.tap()
        let save = app.buttons["Salvar"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)

        type("Salada de atum", into: "campo-nome")
        type("300", into: "campo-calories")
        type("30", into: "campo-protein")
        type("10", into: "campo-carbs")
        type("15,5", into: "campo-fat")
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(button(startingWith: "Salada de atum").waitForExistence(timeout: 5))
        // 1.330 kcal do demo + 300
        XCTAssertTrue(app.staticTexts["1.630 kcal"].exists)
    }

    func testRepeatMeal() {
        launch("-demo", "-demo-tab", "1")

        app.buttons["Adicionar refeição"].firstMatch.tap()
        app.buttons["Repetir refeição anterior"].tap()

        // Refeição de ontem aparece na lista para repetir
        let template = button(startingWith: "Omelete de queijo")
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()

        XCTAssertEqual(app.textFields["campo-nome"].value as? String, "Omelete de queijo")
        app.buttons["Salvar"].tap()

        // Agora existe também hoje
        XCTAssertTrue(button(startingWith: "Omelete de queijo").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1.780 kcal"].exists, "1.330 + 450")
    }

    func testSwipeToDelete() {
        launch("-demo", "-demo-tab", "1")

        let row = button(startingWith: "Iogurte com whey")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Apagar"].tap()

        XCTAssertFalse(row.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1.070 kcal"].exists, "1.330 − 260")
    }

    func testSwipeToEdit() {
        launch("-demo", "-demo-tab", "1")

        let row = button(startingWith: "Iogurte com whey")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Editar"].tap()

        XCTAssertTrue(app.navigationBars["Editar refeição"].waitForExistence(timeout: 5))
        replace("campo-calories", with: "200")
        XCTAssertEqual(app.textFields["campo-calories"].value as? String, "200")
        app.buttons["Salvar"].tap()

        XCTAssertTrue(app.staticTexts["1.270 kcal"].waitForExistence(timeout: 5), "1.330 − 260 + 200")
    }
}
