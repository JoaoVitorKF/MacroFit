import XCTest

/// Teste de interface do registro de peso (modo demo: perfil com 80 kg, meta 2.345 kcal).
final class WeightUITests: XCTestCase {

    func testRecordingWeightUpdatesGoals() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo", "-demo-tab", "2"]
        app.launch()

        XCTAssertTrue(app.staticTexts["2.345"].waitForExistence(timeout: 5))

        app.buttons["Registrar peso"].firstMatch.tap()

        // O campo já vem com o peso atual (80); troca por 78
        let field = app.textFields["campo-weight"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // Dois toques selecionam o número inteiro; digitar substitui a seleção
        field.doubleTap()
        field.typeText("78")
        XCTAssertEqual(field.value as? String, "78")
        app.buttons["Salvar"].tap()

        // Aviso visível junto do card, com as metas novas: 78 kg → 2.319 kcal, proteína 156 g
        XCTAssertTrue(app.staticTexts["Metas atualizadas"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2.319 kcal"].exists)
        XCTAssertTrue(app.staticTexts["156 g"].exists)
        XCTAssertTrue(app.staticTexts["78 kg"].exists, "Peso atual do card")

        // Guarda um print do aviso no resultado do teste (para conferência visual)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "aviso-metas-atualizadas"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // Fechar o aviso
        app.buttons["Fechar aviso"].tap()
        XCTAssertFalse(app.staticTexts["Metas atualizadas"].waitForExistence(timeout: 1))

        // No topo, o resumo de metas também mudou
        app.swipeDown()
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["2.319"].waitForExistence(timeout: 3))
    }
}
