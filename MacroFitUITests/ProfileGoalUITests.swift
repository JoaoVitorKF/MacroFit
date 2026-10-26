import XCTest

/// Objetivo e ritmo de perda no Perfil (modo demo: homem 30a, 80 kg, 180 cm, moderado → TDEE 2.759 kcal).
final class ProfileGoalUITests: XCTestCase {

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

    private var projection: XCUIElement {
        app.descendants(matching: .any)["previsao-peso"].firstMatch
    }

    func testRecompositionShowsWeeklyProjection() {
        // −413,85 kcal/dia → ≈ 0,38 kg por semana
        XCTAssertTrue(projection.waitForExistence(timeout: 5))
        XCTAssertTrue(projection.label.contains("0,38 kg por semana"), projection.label)
    }

    func testLoseFatWithPace() {
        app.navigationBars.buttons["Editar"].tap()
        let loseFat = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Emagrecer")).firstMatch
        for _ in 0..<4 where !loseFat.isHittable { app.swipeUp() }
        loseFat.tap()

        // O ritmo aparece só para emagrecer; o padrão é o moderado (0,75% = 0,6 kg/semana → 2.099 kcal)
        let pace = app.segmentedControls["ritmo"]
        XCTAssertTrue(pace.waitForExistence(timeout: 3))
        XCTAssertTrue(pace.buttons["Moderado"].isSelected)
        for _ in 0..<4 where !app.staticTexts["2.099"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["2.099"].exists, "Meta com o ritmo moderado")
        XCTAssertTrue(projection.label.contains("0,6 kg por semana"), projection.label)

        // Rápido: 1% = 0,8 kg/semana → 880 kcal de déficit → 1.879 kcal
        for _ in 0..<4 where !pace.isHittable { app.swipeDown() }
        pace.buttons["Rápido"].tap()
        for _ in 0..<4 where !app.staticTexts["1.879"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["1.879"].exists, "Meta com o ritmo rápido")
        XCTAssertTrue(projection.label.contains("0,8 kg por semana"), projection.label)
        keepScreenshot("ritmo-rapido")

        app.navigationBars.buttons["Salvar"].tap()
        let paceRow = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Rápido (1% do peso por semana)")).firstMatch
        for _ in 0..<5 where !paceRow.exists { app.swipeUp() }
        XCTAssertTrue(paceRow.exists, "O Perfil mostra o ritmo salvo")
        keepScreenshot("perfil-ritmo")
    }
}
