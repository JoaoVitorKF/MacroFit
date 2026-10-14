import XCTest
@testable import MacroFit

/// "Quanto posso comer?": orçamento da refeição e sugestão de gramas.
/// Metas de referência: 2.345,15 kcal, P 160 g, C 264,3 g, G 72 g (homem 30a/80kg/180cm moderado).
final class MealPlannerTests: XCTestCase {

    private let targets = NutritionCalculator.targets(for: NutritionInput(
        sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .recomposition
    ))
    private let db = FoodDatabase.shared
    private func per100(_ tacoId: Int) -> Macros { db.food(tacoId: tacoId)!.per100g }

    // MARK: - Orçamento

    func testFirstMealOfTheDayGetsItsShare() {
        // Nada registrado: café = 25% do dia
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .breakfast)
        XCTAssertEqual(budget.calories, targets.calories * 0.25, accuracy: 0.1)
        XCTAssertEqual(budget.protein, 40, accuracy: 0.1)
    }

    func testLunchAfterBreakfast() {
        // Café já registrado (500 kcal, 30 g P). Sobram 1.845,15 kcal para almoço+lanche+jantar (35/75 do resto)
        let consumed = Macros(calories: 500, protein: 30, carbs: 60, fat: 15)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: consumed, loggedTypes: [.breakfast], for: .lunch)
        XCTAssertEqual(budget.calories, 1845.15 * 0.35 / 0.75, accuracy: 0.2)
        XCTAssertEqual(budget.protein, 130 * 0.35 / 0.75, accuracy: 0.1)
    }

    func testLastMealGetsEverythingLeft() {
        let consumed = Macros(calories: 1700, protein: 110, carbs: 200, fat: 50)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: consumed, loggedTypes: [.breakfast, .lunch, .snack], for: .dinner)
        XCTAssertEqual(budget.calories, 645.15, accuracy: 0.2)
        XCTAssertEqual(budget.protein, 50, accuracy: 0.1)
    }

    func testNothingLeftGivesZeroBudget() {
        let consumed = Macros(calories: 2600, protein: 170, carbs: 300, fat: 90)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: consumed, loggedTypes: [.breakfast, .lunch], for: .dinner)
        XCTAssertEqual(budget.calories, 0)
        XCTAssertEqual(budget.protein, 0, "Nunca negativo")
    }

    func testSecondSnackStillCountsAsPending() {
        // Já houve lanche, mas este é outro lanche: ele entra na divisão
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [.snack], for: .snack)
        XCTAssertGreaterThan(budget.calories, 0)
    }

    // MARK: - Sugestão de gramas

    func testRiceAndBeefFitLunch() {
        // Almoço com tudo por fazer: 35% do dia ≈ 820,8 kcal, P 56, C 92,5, G 25,2
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .lunch)
        let foods = [per100(3), per100(377), per100(561)] // arroz, patinho, feijão
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget)
        let total = MealPlanner.total(of: foods, grams: grams)

        XCTAssertLessThanOrEqual(total.calories, budget.calories, "Não passa das calorias")
        XCTAssertGreaterThan(total.calories, budget.calories * 0.85, "Aproveita bem o orçamento")
        XCTAssertEqual(total.protein, budget.protein, accuracy: budget.protein * 0.15, "Proteína perto da meta")
        XCTAssertTrue(grams.allSatisfy { $0.truncatingRemainder(dividingBy: 5) == 0 }, "De 5 em 5 g: \(grams)")
        XCTAssertTrue(grams.allSatisfy { (20...600).contains($0) }, "Quantidades razoáveis: \(grams)")
    }

    func testSingleDishIsCappedByCalories() {
        // Só arroz carreteiro no jantar, com 500 kcal sobrando
        let budget = Macros(calories: 500, protein: 40, carbs: 50, fat: 15)
        let grams = MealPlanner.suggestGrams(for: [per100(526)], budget: budget)
        let kcal = per100(526).calories * grams[0] / 100
        XCTAssertLessThanOrEqual(kcal, 500)
        XCTAssertGreaterThan(kcal, 400, "Usa quase todo o orçamento: \(grams[0]) g")
    }

    func testLowCalorieFoodsStayReasonable() {
        // Alface quase não tem calorias: não deve virar 600 g
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .lunch)
        let foods = [per100(410), per100(3), per100(78)] // frango, arroz, alface crespa
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget)
        XCTAssertLessThanOrEqual(grams[2], 150, "Alface: \(grams[2]) g")
    }

    func testChosenFoodDoesNotVanish() {
        // Lanche com banana e aveia: a banana não pode virar 20 g
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .snack)
        let grams = MealPlanner.suggestGrams(for: [per100(182), per100(7)], budget: budget)
        XCTAssertGreaterThanOrEqual(grams[0], 45, "Banana: \(grams[0]) g")
    }

    func testFormSuggestPortions() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        form.add(db.food(tacoId: 3)!)
        form.add(db.food(tacoId: 377)!)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .lunch)
        form.suggestPortions(budget: budget)
        XCTAssertNotEqual(form.items.map(\.grams), [100, 100])
        XCTAssertLessThanOrEqual(form.itemsTotal!.calories, budget.calories)
        XCTAssertEqual(form.portion, .one)
    }

    func testZeroBudgetGivesMinimum() {
        let grams = MealPlanner.suggestGrams(for: [per100(3), per100(377)], budget: .zero)
        XCTAssertEqual(grams, [20, 20])
    }

    func testEmptyFoods() {
        XCTAssertEqual(MealPlanner.suggestGrams(for: [], budget: Macros(calories: 500, protein: 30, carbs: 50, fat: 10)), [])
    }
}
