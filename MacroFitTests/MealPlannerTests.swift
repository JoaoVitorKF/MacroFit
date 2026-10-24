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

    // MARK: - Quantidades fixas e unidades

    func testFixedFoodKeepsItsGramsAndCountsInTheBudget() {
        // Jantar com 1.015 kcal: 300 g de arroz ditos no texto (384 kcal) ficam; o patinho cabe no resto
        let budget = Macros(calories: 1015, protein: 45, carbs: 100, fat: 30)
        let foods = [per100(3), per100(377)]
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget, fixed: [300, nil])
        XCTAssertEqual(grams[0], 300)
        let total = MealPlanner.total(of: foods, grams: grams)
        XCTAssertLessThanOrEqual(total.calories, budget.calories)
        XCTAssertGreaterThan(grams[1], 100, "Sobram ~630 kcal para o patinho: \(grams[1]) g")
    }

    func testAllFixedIsUntouched() {
        let grams = MealPlanner.suggestGrams(for: [per100(3), per100(377)], budget: .zero, fixed: [150, 120])
        XCTAssertEqual(grams, [150, 120])
    }

    func testFixedOverBudgetLeavesMinimumForTheRest() {
        // 600 g de arroz já passam das 500 kcal: o feijão fica no mínimo
        let budget = Macros(calories: 500, protein: 30, carbs: 60, fat: 15)
        let grams = MealPlanner.suggestGrams(for: [per100(3), per100(561)], budget: budget, fixed: [600, nil])
        XCTAssertEqual(grams, [600, MealPlanner.minGrams])
    }

    func testCountedFoodsBecomeWholeUnits() {
        // Café com ovo e pão francês: unidades inteiras, sem passar das calorias
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .breakfast)
        let foods = [per100(488), per100(53), per100(182)] // ovo cozido, pão francês, banana prata
        let units = [488, 53, 182].map { FoodUnits.byTacoId[$0] }
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget, fixed: [nil, nil, nil], units: units)
        XCTAssertEqual(grams[0].truncatingRemainder(dividingBy: 50), 0, "Ovos inteiros: \(grams[0]) g")
        XCTAssertEqual(grams[1].truncatingRemainder(dividingBy: 50), 0, "Pães inteiros: \(grams[1]) g")
        XCTAssertEqual(grams[2].truncatingRemainder(dividingBy: 90), 0, "Bananas inteiras: \(grams[2]) g")
        XCTAssertTrue(grams.allSatisfy { $0 > 0 })
        XCTAssertLessThanOrEqual(MealPlanner.total(of: foods, grams: grams).calories, budget.calories)
    }

    func testUnitsRoundAroundTheOtherFoods() {
        // Ovos (contados) com aveia (por gramas): a aveia se ajusta em volta dos ovos inteiros
        let budget = Macros(calories: 450, protein: 30, carbs: 45, fat: 15)
        let foods = [per100(488), per100(7)]
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget, fixed: [nil, nil], units: [FoodUnits.byTacoId[488], nil])
        XCTAssertEqual(grams[0].truncatingRemainder(dividingBy: 50), 0)
        XCTAssertEqual(grams[1].truncatingRemainder(dividingBy: 5), 0)
        XCTAssertLessThanOrEqual(MealPlanner.total(of: foods, grams: grams).calories, 450)
    }

    func testAtLeastOneUnit() {
        // Quase nada sobrando: ainda assim 1 ovo, não 0
        let grams = MealPlanner.suggestGrams(for: [per100(488)], budget: Macros(calories: 30, protein: 3, carbs: 1, fat: 2), fixed: [nil], units: [FoodUnits.byTacoId[488]])
        XCTAssertEqual(grams, [50])
    }

    func testUnitsHaveAReasonableMaximum() {
        // Jantar com 1.015 kcal e muito carbo sobrando: o pão para em 3, mesmo cabendo mais
        let budget = Macros(calories: 1015, protein: 45, carbs: 141, fat: 35)
        let foods = [per100(488), per100(53)]
        let units = [488, 53].map { FoodUnits.byTacoId[$0] }
        let grams = MealPlanner.suggestGrams(for: foods, budget: budget, fixed: [100, nil], units: units)
        XCTAssertEqual(grams[0], 100, "2 ovos ditos ficam")
        XCTAssertLessThanOrEqual(grams[1], 150, "No máximo 3 pães: \(grams[1]) g")
    }

    func testFoodUnitsDescription() {
        let egg = FoodUnits.byTacoId[488]!
        XCTAssertEqual(egg.describe(grams: 100), "2 ovos")
        XCTAssertEqual(egg.describe(grams: 50), "1 ovo")
        XCTAssertEqual(egg.describe(grams: 75), "1,5 ovos")
        XCTAssertNil(egg.describe(grams: 10))
        XCTAssertEqual(FoodUnits.unit(forFoodId: "taco-53")?.plural, "pães")
        XCTAssertNil(FoodUnits.unit(forFoodId: "taco-3"), "Arroz é por gramas")
        XCTAssertNil(FoodUnits.unit(forFoodId: "custom-\(UUID().uuidString)"))
        XCTAssertNil(FoodUnits.unit(forFoodId: "taco-209"), "Suco de laranja não é contado")
    }

    // MARK: - Formulário: texto, cadeado e reequilíbrio

    func testTextWithoutQuantitiesGetsSuggestedGrams() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .lunch)
        let outcome = form.addFromText("arroz, feijão e frango", budget: budget)
        XCTAssertEqual(outcome.added, 3)
        XCTAssertEqual(outcome.suggested, 3)
        XCTAssertFalse(form.items.contains { $0.isLocked })
        XCTAssertNotEqual(form.items.map(\.grams), [100, 100, 100], "Não fica nos 100 g padrão")
        XCTAssertLessThanOrEqual(form.itemsTotal!.calories, budget.calories)
    }

    func testTextQuantitiesAreLocked() {
        let form = MealFormViewModel(day: .now, type: .breakfast)
        let budget = Macros(calories: 500, protein: 35, carbs: 50, fat: 15)
        let outcome = form.addFromText("2 ovos e pão", budget: budget)
        XCTAssertEqual(outcome.suggested, 1)
        XCTAssertEqual(form.items[0].grams, 100, "2 ovos = 100 g, como dito")
        XCTAssertTrue(form.items[0].isLocked)
        XCTAssertFalse(form.items[1].isLocked)
        XCTAssertEqual(form.items[1].grams!.truncatingRemainder(dividingBy: 50), 0, "Pão francês inteiro")

        // A sugestão do botão também respeita o cadeado
        form.suggestPortions(budget: Macros(calories: 300, protein: 20, carbs: 30, fat: 10))
        XCTAssertEqual(form.items[0].grams, 100)
    }

    func testTextKeepsItemsAlreadyInTheMeal() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        form.add(db.food(tacoId: 3)!, grams: 250)
        let budget = Macros(calories: 800, protein: 50, carbs: 90, fat: 25)
        form.addFromText("frango", budget: budget)
        XCTAssertEqual(form.items[0].grams, 250, "O arroz que já estava não muda")
        XCTAssertLessThanOrEqual(form.itemsTotal!.calories, 800)
    }

    func testTextWithoutBudgetUsesDefaultGrams() {
        let form = MealFormViewModel(day: .now)
        let outcome = form.addFromText("arroz")
        XCTAssertEqual(outcome.suggested, 0)
        XCTAssertEqual(form.items[0].grams, MealFormViewModel.defaultGrams)
    }

    func testAdjustLocksAndRebalances() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        let budget = MealPlanner.budget(targets: targets, consumedByOthers: .zero, loggedTypes: [], for: .lunch)
        form.addFromText("arroz e patinho", budget: budget)
        let riceBefore = form.items[0].grams!
        let beefBefore = form.items[1].grams!

        // Mais arroz: o arroz trava e o patinho diminui para continuar cabendo
        for _ in 0..<5 { form.adjustAndRebalance(form.items[0].id, by: 10, budget: budget) }
        XCTAssertEqual(form.items[0].grams, riceBefore + 50)
        XCTAssertTrue(form.items[0].isLocked)
        XCTAssertLessThan(form.items[1].grams!, beefBefore)
        XCTAssertLessThanOrEqual(form.itemsTotal!.calories, budget.calories)

        form.toggleLock(form.items[0].id)
        XCTAssertFalse(form.items[0].isLocked)
    }

    func testEmptyFoods() {
        XCTAssertEqual(MealPlanner.suggestGrams(for: [], budget: Macros(calories: 500, protein: 30, carbs: 50, fat: 10)), [])
    }
}
