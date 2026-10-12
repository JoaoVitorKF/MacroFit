import XCTest
@testable import MacroFit

/// Testes das regras de comemoração e de dicas (meta de referência: 2.345 kcal e 160 g de proteína).
final class DailyCoachTests: XCTestCase {

    private let targets = NutritionCalculator.targets(for: NutritionInput(
        sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .recomposition
    ))

    private func macros(kcal: Double, protein: Double) -> Macros {
        Macros(calories: kcal, protein: protein, carbs: 0, fat: 0)
    }

    private func meal(_ name: String, kcal: Double, protein: Double, at seconds: TimeInterval = 0) -> Meal {
        let meal = Meal(name: name, type: .snack, day: .now, calories: kcal, protein: protein, carbs: 0, fat: 0)
        meal.createdAt = Date(timeIntervalSince1970: seconds)
        return meal
    }

    // MARK: - Comemoração

    func testProteinGoalCrossed() {
        let result = DailyCoach.achievements(before: macros(kcal: 1330, protein: 115), after: macros(kcal: 1980, protein: 167), targets: targets)
        XCTAssertEqual(result, [.proteinGoal])
    }

    func testNoCelebrationWhenAlreadyAboveGoal() {
        let result = DailyCoach.achievements(before: macros(kcal: 1500, protein: 170), after: macros(kcal: 1700, protein: 190), targets: targets)
        XCTAssertTrue(result.isEmpty, "Só comemora no momento em que cruza")
    }

    func testNoCelebrationWhenGoingDown() {
        let result = DailyCoach.achievements(before: macros(kcal: 2300, protein: 170), after: macros(kcal: 1000, protein: 100), targets: targets)
        XCTAssertTrue(result.isEmpty, "Apagar refeição não comemora")
    }

    func testCaloriesEnterRange() {
        // 95% de 2.345,15 = 2.227,9; 105% = 2.462,4
        let result = DailyCoach.achievements(before: macros(kcal: 1900, protein: 100), after: macros(kcal: 2300, protein: 140), targets: targets)
        XCTAssertEqual(result, [.caloriesInRange])
    }

    func testCaloriesJumpPastRangeIsNotCelebrated() {
        let result = DailyCoach.achievements(before: macros(kcal: 1900, protein: 100), after: macros(kcal: 2600, protein: 140), targets: targets)
        XCTAssertTrue(result.isEmpty, "Passou direto da meta: não é conquista")
    }

    func testBothAtOnce() {
        let after = macros(kcal: 2300, protein: 165)
        let result = DailyCoach.achievements(before: macros(kcal: 1800, protein: 120), after: after, targets: targets)
        XCTAssertEqual(result, [.proteinGoal, .caloriesInRange])
        XCTAssertTrue(DailyCoach.celebrationMessage(for: result, consumed: after, targets: targets).contains("Proteína e calorias"))
    }

    // MARK: - Dicas

    func testNoMealsMorning() {
        let tip = DailyCoach.tip(consumed: .zero, targets: targets, mealCount: 0, hour: 8)
        XCTAssertEqual(tip.title, "Bom dia!")
    }

    func testNoMealsAfternoon() {
        let tip = DailyCoach.tip(consumed: .zero, targets: targets, mealCount: 0, hour: 15)
        XCTAssertEqual(tip.title, "Nada registrado hoje")
    }

    func testOverCaloriesWarning() {
        let tip = DailyCoach.tip(consumed: macros(kcal: 2700, protein: 120), targets: targets, mealCount: 4, hour: 21)
        XCTAssertEqual(tip.tone, .warning)
        XCTAssertTrue(tip.title.contains("acima da meta"))
    }

    func testRoundDay() {
        let tip = DailyCoach.tip(consumed: macros(kcal: 2300, protein: 165), targets: targets, mealCount: 4, hour: 21)
        XCTAssertEqual(tip.title, "Dia redondo")
        XCTAssertEqual(tip.tone, .success)
    }

    func testProteinDoneCaloriesMissing() {
        let tip = DailyCoach.tip(consumed: macros(kcal: 1600, protein: 162), targets: targets, mealCount: 3, hour: 15)
        XCTAssertEqual(tip.title, "Proteína batida!")
    }

    func testSuggestsBestProteinPerCalorieThatFits() {
        // Faltam 45 g de proteína e 1.015 kcal
        let history = [
            meal("Iogurte com whey", kcal: 260, protein: 35, at: 1),       // 0,135 g/kcal ← melhor
            meal("Frango com arroz", kcal: 650, protein: 52, at: 2),       // 0,080
            meal("Picanha", kcal: 1200, protein: 60, at: 3),               // não cabe nas calorias
            meal("Whey duplo + aveia", kcal: 500, protein: 70, at: 4),     // proteína demais (> 45 + 10)
            meal("Banana", kcal: 100, protein: 1, at: 5),                  // pouca proteína
        ]
        let tip = DailyCoach.tip(consumed: macros(kcal: 1330, protein: 115), targets: targets, mealCount: 3, hour: 15, history: history)
        XCTAssertEqual(tip.suggestion?.name, "Iogurte com whey")
        XCTAssertTrue(tip.title.contains("proteína"))
    }

    func testGenericProteinTipWithoutHistory() {
        let tip = DailyCoach.tip(consumed: macros(kcal: 1330, protein: 115), targets: targets, mealCount: 3, hour: 19)
        XCTAssertNil(tip.suggestion)
        XCTAssertTrue(tip.message.contains("frango"))
        XCTAssertTrue(tip.message.contains("jantar"), "À noite lembra que ainda dá tempo")
    }

    func testLateNightLowCalories() {
        // Proteína quase lá (faltam 10 g < 15), mas só 55% das calorias às 21h
        let tip = DailyCoach.tip(consumed: macros(kcal: 1300, protein: 150), targets: targets, mealCount: 2, hour: 21)
        XCTAssertTrue(tip.title.hasPrefix("Faltam"))
        XCTAssertTrue(tip.message.contains("massa"))
    }

    func testDefaultSummary() {
        let tip = DailyCoach.tip(consumed: macros(kcal: 1800, protein: 150), targets: targets, mealCount: 3, hour: 14)
        XCTAssertEqual(tip.title, "Quase lá")
    }
}
