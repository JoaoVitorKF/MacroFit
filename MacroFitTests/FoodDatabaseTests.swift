import XCTest
@testable import MacroFit

/// Testes da tabela de alimentos (TACO embutida) e da busca.
final class FoodDatabaseTests: XCTestCase {

    private let database = FoodDatabase.shared
    private let accuracy = 0.001

    private func firstName(_ query: String) -> String? {
        database.search(query).first?.name
    }

    // MARK: - Dados

    func testLoadsTaco() {
        // 597 da TACO menos 6 sem calorias (em reanálise / sal)
        XCTAssertEqual(database.foods.count, 591)
    }

    func testValuesMatchTaco() {
        // Valores da TACO 4ª edição, por 100 g
        let rice = database.food(tacoId: 3)
        XCTAssertEqual(rice?.name, "Arroz, tipo 1, cozido")
        XCTAssertEqual(rice?.per100g, Macros(calories: 128, protein: 2.5, carbs: 28.1, fat: 0.2))

        let beans = database.food(tacoId: 561)
        XCTAssertEqual(beans?.per100g, Macros(calories: 76, protein: 4.8, carbs: 13.6, fat: 0.5))

        let chicken = database.food(tacoId: 410)
        XCTAssertEqual(chicken?.name, "Frango, peito, sem pele, grelhado")
        XCTAssertEqual(chicken?.per100g, Macros(calories: 159, protein: 32, carbs: 0, fat: 2.5))

        let carreteiro = database.food(tacoId: 526)
        XCTAssertEqual(carreteiro?.per100g, Macros(calories: 154, protein: 10.8, carbs: 11.6, fat: 7.1))
    }

    func testOilsHaveOnlyFat() {
        // "NA" (não se aplica) vira 0
        let oliveOil = database.food(tacoId: 260)
        XCTAssertEqual(oliveOil?.per100g, Macros(calories: 884, protein: 0, carbs: 0, fat: 100))
    }

    func testFoodsWithoutCaloriesAreExcluded() {
        XCTAssertNil(database.food(tacoId: 458), "Leite integral está em reanálise na TACO (sem valores)")
        XCTAssertNil(database.food(tacoId: 517), "Sal grosso não tem calorias")
    }

    func testMacrosForGrams() {
        // 200 g de arroz: 2 × (128 kcal, 2,5 P, 28,1 C, 0,2 G)
        let rice = database.food(tacoId: 3)!
        XCTAssertEqual(rice.macros(grams: 200), Macros(calories: 256, protein: 5, carbs: 56.2, fat: 0.4))
        // 150 g de patinho grelhado: 1,5 × (219 kcal, 35,9 P, 0 C, 7,3 G)
        let beef = database.food(tacoId: 377)!
        XCTAssertEqual(beef.macros(grams: 150).calories, 328.5, accuracy: accuracy)
        XCTAssertEqual(beef.macros(grams: 150).protein, 53.9, accuracy: 0.051)
    }

    func testAllAliasesPointToExistingFoods() {
        for alias in FoodSearch.aliases {
            for id in alias.tacoIds {
                XCTAssertNotNil(database.food(tacoId: id), "Apelido \(alias.key) aponta para TACO \(id), que não existe")
            }
        }
        for id in FoodSearch.commonTacoIds {
            XCTAssertNotNil(database.food(tacoId: id))
        }
    }

    // MARK: - Busca

    func testSearchPrefersCookedEverydayFoods() {
        XCTAssertEqual(firstName("arroz"), "Arroz, tipo 1, cozido")
        XCTAssertEqual(firstName("frango"), "Frango, peito, sem pele, grelhado")
        XCTAssertEqual(firstName("carne"), "Carne, bovina, patinho, sem gordura, grelhado")
        XCTAssertEqual(firstName("carne moída"), "Carne, bovina, acém, moído, cozido")
        XCTAssertEqual(firstName("batata doce"), "Batata, doce, cozida")
        XCTAssertEqual(firstName("peito de frango"), "Frango, peito, sem pele, grelhado")
    }

    func testSearchIgnoresAccentsCaseAndPlural() {
        XCTAssertEqual(firstName("FEIJAO"), "Feijão, carioca, cozido")
        XCTAssertEqual(firstName("ovos"), "Ovo, de galinha, inteiro, cozido/10minutos")
        XCTAssertEqual(firstName("pao"), "Pão, trigo, francês")
    }

    func testSearchSynonyms() {
        XCTAssertEqual(firstName("aipim"), "Mandioca, cozida")
        XCTAssertEqual(firstName("macaxeira"), "Mandioca, cozida")
    }

    func testSearchPreparedDishes() {
        XCTAssertEqual(firstName("carreteiro"), "Arroz carreteiro")
        XCTAssertEqual(firstName("feijoada"), "Feijoada")
    }

    func testRawOnlyWhenAsked() {
        let results = database.search("arroz").map(\.name)
        let firstRaw = results.firstIndex { $0.contains("cru") }!
        let lastCooked = results.lastIndex { $0.contains("cozido") }!
        XCTAssertGreaterThan(firstRaw, lastCooked, "Crus depois dos cozidos")
        XCTAssertEqual(firstName("arroz cru"), "Arroz, tipo 1, cru")
    }

    func testSearchWithoutMatch() {
        XCTAssertTrue(database.search("xyzabc").isEmpty)
    }

    func testEmptySearchShowsCommonFoods() {
        let common = database.search("  ")
        XCTAssertEqual(common.first?.name, "Arroz, tipo 1, cozido")
        XCTAssertEqual(common.count, FoodSearch.commonTacoIds.count)
    }

    func testCustomFoodsComeFirst() {
        let whey = CustomFood(name: "Whey protein baunilha", per100g: Macros(calories: 400, protein: 80, carbs: 8, fat: 6)).food
        let results = database.search("whey", custom: [whey])
        XCTAssertEqual(results.first, whey)

        let yogurt = CustomFood(name: "Iogurte grego zero", per100g: Macros(calories: 60, protein: 10, carbs: 4, fat: 0)).food
        XCTAssertEqual(database.search("iogurte", custom: [yogurt]).first, yogurt, "Alimento próprio vem antes da TACO")
    }

    func testLabelPortionConvertsTo100g() {
        // Rótulo: porção de 30 g = 120 kcal, 24 g P, 3 g C, 1,5 g G → por 100 g: 400 / 80 / 10 / 5
        let per100 = CustomFood.per100g(fromPortion: Macros(calories: 120, protein: 24, carbs: 3, fat: 1.5), grams: 30)
        XCTAssertEqual(per100, Macros(calories: 400, protein: 80, carbs: 10, fat: 5))
    }
}
