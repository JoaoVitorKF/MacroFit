import XCTest

/// Montar refeição por alimentos e gramas (modo demo: faltam 1.015 kcal hoje).
final class FoodMealUITests: XCTestCase {

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

    /// Busca e escolhe um alimento na tela "Adicionar alimento".
    private func addFood(search: String, pick name: String) {
        app.buttons["adicionar-alimento"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText(search)
        let food = app.buttons["alimento-\(name)"]
        XCTAssertTrue(food.waitForExistence(timeout: 5), "\(name) aparece ao buscar \"\(search)\"")
        food.tap()
    }

    /// Troca os gramas de um alimento (dois toques selecionam o número).
    private func setGrams(_ grams: String, for name: String) {
        let field = app.textFields["gramas-\(name)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.doubleTap()
        field.typeText(grams)
        app.toolbars.buttons["OK"].tap()
    }

    func testBuildMealFromFoodsAndGrams() {
        app.buttons["Adicionar refeição"].firstMatch.tap()
        XCTAssertTrue(app.segmentedControls["modo-entrada"].buttons["Por alimentos"].waitForExistence(timeout: 5))

        addFood(search: "arroz", pick: "Arroz, tipo 1, cozido")
        // 100 g de arroz = 128 kcal
        XCTAssertTrue(app.staticTexts["128 kcal"].waitForExistence(timeout: 3))
        setGrams("200", for: "Arroz, tipo 1, cozido")
        XCTAssertTrue(app.staticTexts["256 kcal"].waitForExistence(timeout: 3), "200 g de arroz = 256 kcal")

        addFood(search: "carne", pick: "Carne, bovina, patinho, sem gordura, grelhado")
        setGrams("140", for: "Carne, bovina, patinho, sem gordura, grelhado")
        // 140 g de patinho = 306,6 kcal; total 562,6 → "563 kcal" (o total fica abaixo do quadro de sugestão)
        let total = app.staticTexts["563 kcal"]
        for _ in 0..<4 where !total.exists { app.swipeUp() }
        XCTAssertTrue(total.waitForExistence(timeout: 3))
        keepScreenshot("refeicao-por-alimentos")

        app.buttons["Salvar"].tap()

        // Na tela Hoje: a meta exata é 2.345,15 kcal; 2.345,15 − 1.330 − 562,6 = 452,55 → "453"
        XCTAssertTrue(app.staticTexts["453"].waitForExistence(timeout: 5))
    }

    func testTypeMealAsText() {
        app.buttons["Adicionar refeição"].firstMatch.tap()
        let field = app.textFields["campo-texto-refeicao"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("200g de arroz e 150g de carne\n")

        // Os dois alimentos entram com os gramas do texto
        XCTAssertEqual(app.textFields["gramas-Arroz, tipo 1, cozido"].value as? String, "200")
        XCTAssertEqual(app.textFields["gramas-Carne, bovina, patinho, sem gordura, grelhado"].value as? String, "150")
        XCTAssertTrue(app.staticTexts["2 alimentos adicionados."].exists)
        keepScreenshot("refeicao-por-texto")

        // Texto com algo que não está na tabela: avisa
        field.tap()
        field.typeText("100g de xyzabc\n")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Não encontrei")).firstMatch.waitForExistence(timeout: 3))
    }

    func testWhatToEatFromToday() {
        // Na tela Hoje: escreve o que vai comer e já vê os gramas, sem montar a refeição
        let field = app.textFields["campo-o-que-comer"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("2 ovos, pão e banana\n")

        // O tipo padrão depende da hora: escolhe o jantar (o demo já tem café, almoço e lanche)
        let types = app.segmentedControls["tipo-plano"]
        XCTAssertTrue(types.waitForExistence(timeout: 5))
        types.buttons["Jantar"].tap()
        XCTAssertTrue(app.staticTexts["Para o jantar sobram ~1.015 kcal"].waitForExistence(timeout: 3))

        // "2 ovos" ficam como foi dito (travados); o pão é sugerido em unidades inteiras, até 3
        let eggs = "Ovo, de galinha, inteiro, cozido/10minutos"
        XCTAssertEqual(app.textFields["gramas-\(eggs)"].value as? String, "100")
        XCTAssertTrue(app.buttons["cadeado-\(eggs)"].exists)
        XCTAssertEqual(app.staticTexts["unidades-\(eggs)"].label, "≈ 2 ovos")
        let bread = Double(app.textFields["gramas-Pão, trigo, francês"].value as? String ?? "") ?? 0
        XCTAssertTrue([50, 100, 150].contains(bread), "Pães inteiros, no máximo 3: \(bread) g")
        keepScreenshot("o-que-vou-comer")

        // Mais pão no + : ele trava e a banana se ajusta
        app.buttons["Mais 10 gramas de Pão francês"].tap()
        XCTAssertTrue(app.buttons["cadeado-Pão, trigo, francês"].waitForExistence(timeout: 3))

        // Registrar salva no jantar e volta para o Hoje
        app.buttons["registrar-plano"].tap()
        XCTAssertFalse(types.waitForExistence(timeout: 2))
        let dinner = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ovo + Pão francês + Banana")).firstMatch
        for _ in 0..<4 where !dinner.exists { app.swipeUp() }
        XCTAssertTrue(dinner.exists, "A refeição aparece no card de refeições")
    }

    func testSuggestPortionsForDinner() {
        // Demo: café, almoço e lanche já registrados → o jantar recebe tudo o que sobra (1.015 kcal)
        let dinnerRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Jantar")).firstMatch
        XCTAssertTrue(dinnerRow.waitForExistence(timeout: 5))
        dinnerRow.tap()

        addFood(search: "frango", pick: "Frango, peito, sem pele, grelhado")
        addFood(search: "batata doce", pick: "Batata, doce, cozida")

        // O quadro fica abaixo dos alimentos: rola até ele (a lista só cria as linhas visíveis)
        let suggest = app.buttons["sugerir-quantidades"]
        for _ in 0..<4 where !suggest.exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Para o jantar sobram ~1.015 kcal"].exists, "Último jantar recebe tudo o que sobra")
        suggest.tap()

        // A refeição cabe no que sobra e aproveita bem
        let usage = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "de 1.015 kcal")).firstMatch
        XCTAssertTrue(usage.waitForExistence(timeout: 3))
        let used = Double(usage.label.components(separatedBy: " ").first!.replacingOccurrences(of: ".", with: "")) ?? 0
        // Frango e batata doce quase não têm gordura: não dá para usar os 35 g de gordura da fatia,
        // então a sugestão fica em ~690 kcal e o app avisa o que sobra
        XCTAssertGreaterThan(used, 650, "Aproveita o que dá com esses alimentos")
        XCTAssertLessThanOrEqual(used, 1015, "Não passa do que sobra")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sobram ~")).firstMatch.exists, "Avisa as calorias de gordura que sobram")
        keepScreenshot("sugestao-jantar")

        // Os gramas mudaram (não são mais os 100 g iniciais)
        for _ in 0..<4 { app.swipeDown() }
        let chicken = app.textFields["gramas-Frango, peito, sem pele, grelhado"]
        XCTAssertTrue(chicken.waitForExistence(timeout: 3))
        XCTAssertNotEqual(chicken.value as? String, "100")
        keepScreenshot("sugestao-jantar-gramas")
    }

    func testPlusMinusButtons() {
        app.buttons["Adicionar refeição"].firstMatch.tap()
        addFood(search: "frango", pick: "Frango, peito, sem pele, grelhado")
        // 100 g = 159 kcal; +10 → 110 g = 174,9 → "175 kcal"
        app.buttons["Mais 10 gramas de Frango"].tap()
        XCTAssertEqual(app.textFields["gramas-Frango, peito, sem pele, grelhado"].value as? String, "110")
        XCTAssertTrue(app.staticTexts["175 kcal"].waitForExistence(timeout: 3))
    }

    func testCustomFoodFromLabel() {
        app.buttons["Adicionar refeição"].firstMatch.tap()
        app.buttons["adicionar-alimento"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("whey")
        app.buttons["Cadastrar alimento pelo rótulo"].tap()

        // Rótulo: porção de 30 g = 120 kcal, 24 g proteína, 3 g carbo, 1,5 g gordura
        let fields: [(String, String)] = [("campo-grams", "30"), ("campo-calories", "120"), ("campo-protein", "24"), ("campo-carbs", "3"), ("campo-fat", "1,5")]
        for (identifier, value) in fields {
            let field = app.textFields[identifier]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.doubleTap()
            field.typeText(value)
            app.toolbars.buttons["OK"].tap()
        }
        XCTAssertTrue(app.staticTexts["400 kcal · P 80 g · C 10 g · G 5 g"].waitForExistence(timeout: 3), "Convertido para 100 g")
        keepScreenshot("alimento-proprio")
        app.navigationBars["Novo alimento"].buttons["Salvar"].tap()

        // Volta para a refeição já com o alimento novo (100 g = 400 kcal)
        XCTAssertTrue(app.textFields["gramas-Whey"].waitForExistence(timeout: 5))
        setGrams("30", for: "Whey")
        XCTAssertTrue(app.staticTexts["120 kcal"].waitForExistence(timeout: 3))
    }
}
