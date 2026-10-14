import XCTest
@testable import MacroFit

/// Refeição escrita ou ditada: "200g de arroz e 150g de carne".
final class MealTextParserTests: XCTestCase {

    private func parse(_ text: String) -> [(name: String?, grams: Double?)] {
        MealTextParser.parse(text).map { ($0.food?.name, $0.grams) }
    }

    func testTypicalLunch() {
        let entries = parse("200g de arroz e 150g de carne")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Arroz, tipo 1, cozido")
        XCTAssertEqual(entries[0].grams, 200)
        XCTAssertEqual(entries[1].name, "Carne, bovina, patinho, sem gordura, grelhado")
        XCTAssertEqual(entries[1].grams, 150)
    }

    func testDictationStyleWithSpacesAndWords() {
        // O ditado do iPhone costuma escrever "200 g" ou "200 gramas"
        let entries = parse("200 gramas de carreteiro")
        XCTAssertEqual(entries.first?.name, "Arroz carreteiro")
        XCTAssertEqual(entries.first?.grams, 200)

        let more = parse("150 g de frango, 100 g de batata doce mais 80 g de feijão.")
        XCTAssertEqual(more.map(\.name), ["Frango, peito, sem pele, grelhado", "Batata, doce, cozida", "Feijão, carioca, cozido"])
        XCTAssertEqual(more.map(\.grams), [150, 100, 80])
    }

    func testWithoutSeparators() {
        let entries = parse("200g arroz 150g feijão")
        XCTAssertEqual(entries.map(\.grams), [200, 150])
        XCTAssertEqual(entries.map(\.name), ["Arroz, tipo 1, cozido", "Feijão, carioca, cozido"])
    }

    func testFoodsWithoutQuantities() {
        let entries = parse("arroz, feijão e frango")
        XCTAssertEqual(entries.count, 3)
        XCTAssertTrue(entries.allSatisfy { $0.grams == nil }, "Sem quantidade: o formulário usa 100 g e o usuário pode pedir a sugestão")
        XCTAssertEqual(entries.last?.name, "Frango, peito, sem pele, grelhado")
    }

    func testUnitsAndCounts() {
        XCTAssertEqual(parse("2 ovos").first?.grams, 100, "2 × 50 g")
        XCTAssertEqual(parse("2 ovos").first?.name, "Ovo, de galinha, inteiro, cozido/10minutos")
        XCTAssertEqual(parse("1 pão francês").first?.grams, 50)
        XCTAssertEqual(parse("duas bananas").first?.grams, 180)
        XCTAssertEqual(parse("1,5 kg de batata doce").first?.grams, 1500)
        XCTAssertEqual(parse("2 colheres de sopa de azeite").first?.grams, 30)
        XCTAssertEqual(parse("1 concha de feijão").first?.grams, 100)
        XCTAssertEqual(parse("200 arroz").first?.grams, 200, "Número grande sem unidade = gramas")
        XCTAssertNil(parse("3 arroz").first?.grams, "Número pequeno sem unidade e sem peso típico: não chuta")
    }

    func testDecimalWithComma() {
        XCTAssertEqual(parse("150,5g de patinho").first?.grams, 151, "Arredonda para grama inteiro")
    }

    func testRiceWithBeansFallsBack() {
        // "arroz com feijão" não é um alimento da tabela: usa a primeira parte
        let entries = parse("200g de arroz com feijão")
        XCTAssertEqual(entries.first?.name, "Arroz, tipo 1, cozido")
    }

    func testUnknownFood() {
        let entries = MealTextParser.parse("150g de xyzabc")
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.food)
        XCTAssertEqual(entries.first?.query, "xyzabc")
    }

    func testCustomFoodsAreUsed() {
        let whey = CustomFood(name: "Whey protein", per100g: Macros(calories: 400, protein: 80, carbs: 8, fat: 6)).food
        let entries = MealTextParser.parse("30g de whey", custom: [whey])
        XCTAssertEqual(entries.first?.food, whey)
        XCTAssertEqual(entries.first?.grams, 30)
    }

    func testEmptyText() {
        XCTAssertTrue(MealTextParser.parse("   ").isEmpty)
        XCTAssertTrue(MealTextParser.parse(" e , ").isEmpty)
    }
}
