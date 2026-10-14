import SwiftData
import XCTest
@testable import MacroFit

/// Montar refeição por alimentos e gramas.
final class MealBuilderTests: XCTestCase {

    private let db = FoodDatabase.shared
    private var rice: Food { db.food(tacoId: 3)! }      // Arroz tipo 1 cozido: 128 kcal, P 2,5, C 28,1, G 0,2
    private var beef: Food { db.food(tacoId: 377)! }    // Patinho grelhado: 219 kcal, P 35,9, C 0, G 7,3
    private let accuracy = 0.051

    private func inMemoryContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    func testTotalsFromGrams() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        form.add(rice)
        form.add(beef)
        XCTAssertEqual(form.items.first?.gramsText, "100", "Começa com 100 g")

        form.items[0].gramsText = "200"
        form.items[1].gramsText = "140"
        // 200 g arroz = 256 kcal, P 5, C 56,2, G 0,4; 140 g patinho = 306,6 kcal, P 50,3, G 10,2
        let total = form.itemsTotal!
        XCTAssertEqual(total.calories, 562.6, accuracy: accuracy)
        XCTAssertEqual(total.protein, 55.3, accuracy: accuracy)
        XCTAssertEqual(total.carbs, 56.2, accuracy: accuracy)
        XCTAssertEqual(total.fat, 10.6, accuracy: accuracy)
        XCTAssertTrue(form.isValid, "Sem nome digitado, usa o automático")
        XCTAssertEqual(form.effectiveName, "Arroz + Patinho")
    }

    func testFoodsModeValidation() {
        let form = MealFormViewModel(day: .now)
        XCTAssertFalse(form.isValid)
        XCTAssertEqual(form.itemsError, "Adicione pelo menos um alimento.")

        form.add(rice)
        form.items[0].gramsText = "0"
        XCTAssertNotNil(form.itemsError, "0 g é inválido")
        form.items[0].gramsText = "3000"
        XCTAssertNotNil(form.itemsError, "Mais de 2 kg é inválido")
        form.items[0].gramsText = "150,5"
        XCTAssertNil(form.itemsError)
        XCTAssertTrue(form.isValid)
    }

    func testAdjustGramsStaysInRange() {
        let form = MealFormViewModel(day: .now)
        form.add(rice, grams: 15)
        let id = form.items[0].id
        form.adjustGrams(of: id, by: 10)
        XCTAssertEqual(form.items[0].grams, 25)
        form.adjustGrams(of: id, by: -10)
        form.adjustGrams(of: id, by: -10)
        form.adjustGrams(of: id, by: -10)
        XCTAssertEqual(form.items[0].grams, 1, "Nunca abaixo de 1 g")
    }

    func testSaveCreatesMealWithItems() throws {
        let context = try inMemoryContext()
        let form = MealFormViewModel(day: .now, type: .lunch)
        form.add(rice, grams: 200)
        form.add(beef, grams: 140)
        XCTAssertTrue(form.save(in: context))

        let meal = try XCTUnwrap(context.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(meal.name, "Arroz + Patinho")
        XCTAssertEqual(meal.items.map(\.grams), [200, 140])
        XCTAssertEqual(meal.calories, 562.6, accuracy: accuracy)
        XCTAssertEqual(meal.itemsSummary, "Arroz 200 g · Patinho 140 g")
    }

    func testEditingMealWithItems() throws {
        let context = try inMemoryContext()
        let meal = Meal(name: "Almoço", type: .lunch, day: .now, items: [MealItem(food: rice, grams: 200)])
        context.insert(meal)

        let form = MealFormViewModel(editing: meal)
        XCTAssertEqual(form.mode, .foods)
        XCTAssertEqual(form.items.first?.grams, 200)
        form.items[0].gramsText = "100"
        form.save(in: context)

        XCTAssertEqual(meal.items.first?.grams, 100)
        XCTAssertEqual(meal.calories, 128, accuracy: accuracy, "Totais recalculados dos itens")
    }

    func testSwitchingToManualClearsItems() throws {
        let context = try inMemoryContext()
        let meal = Meal(name: "Almoço", type: .lunch, day: .now, items: [MealItem(food: rice, grams: 200)])
        context.insert(meal)

        let form = MealFormViewModel(editing: meal)
        form.mode = .manual
        form.caloriesText = "300"
        form.save(in: context)

        XCTAssertTrue(meal.items.isEmpty)
        XCTAssertEqual(meal.calories, 300)
    }

    func testPortionScalesGrams() {
        let template = Meal(name: "Almoço", type: .lunch, day: .now, items: [MealItem(food: rice, grams: 200), MealItem(food: beef, grams: 150)])
        let form = MealFormViewModel(day: .now, template: template, portion: .half)
        XCTAssertEqual(form.mode, .foods)
        XCTAssertEqual(form.items.map(\.grams), [100, 75])
        form.apply(.double)
        XCTAssertEqual(form.items.map(\.grams), [400, 300], "Sempre a partir da referência")
    }

    func testQuickAddCopiesItems() throws {
        let context = try inMemoryContext()
        let template = Meal(name: "Almoço", type: .lunch, day: .now, items: [MealItem(food: rice, grams: 200)])
        context.insert(template)

        let added = MealQuickAdd.add(template, portion: .oneAndHalf, on: .now, in: context)
        XCTAssertEqual(added.items.map(\.grams), [300])
        XCTAssertEqual(added.calories, 384, accuracy: accuracy, "300 g de arroz = 3 × 128")
        XCTAssertNotEqual(added.items.first?.id, template.items.first?.id, "Itens copiados, não compartilhados")
    }

    func testItemsSurviveSaveAndFetch() throws {
        let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let writer = ModelContext(container)
        writer.insert(Meal(name: "Jantar", type: .dinner, day: .now, items: [MealItem(food: beef, grams: 120)]))
        try writer.save()

        let reader = ModelContext(container)
        let meal = try XCTUnwrap(reader.fetch(FetchDescriptor<Meal>()).first)
        XCTAssertEqual(meal.items.first?.name, "Carne, bovina, patinho, sem gordura, grelhado")
        XCTAssertEqual(meal.items.first?.per100g.protein, 35.9)
    }

    func testOldMealsWithoutItemsStillWork() {
        let meal = Meal(name: "Antiga", type: .snack, day: .now, calories: 200, protein: 10, carbs: 20, fat: 5)
        XCTAssertTrue(meal.items.isEmpty)
        XCTAssertNil(meal.itemsData)
        XCTAssertEqual(MealFormViewModel(editing: meal).mode, .manual)
    }

    func testShortNames() {
        XCTAssertEqual(MealItem(food: rice, grams: 1).shortName, "Arroz")
        XCTAssertEqual(MealItem(food: beef, grams: 1).shortName, "Patinho")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 410)!, grams: 1).shortName, "Frango")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 88)!, grams: 1).shortName, "Batata doce")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 561)!, grams: 1).shortName, "Feijão carioca")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 53)!, grams: 1).shortName, "Pão francês")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 488)!, grams: 1).shortName, "Ovo")
        XCTAssertEqual(MealItem(food: db.food(tacoId: 526)!, grams: 1).shortName, "Arroz carreteiro")
    }
}
