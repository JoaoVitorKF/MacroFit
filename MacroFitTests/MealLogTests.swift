import XCTest
@testable import MacroFit

/// Testes da lógica de refeições: agrupamento do dia, histórico para "repetir",
/// validação do formulário e navegação entre dias.
final class MealLogTests: XCTestCase {

    private func meal(_ name: String, _ type: MealType, kcal: Double = 100, p: Double = 10, c: Double = 10, g: Double = 2, createdAt: Date = .now) -> Meal {
        let meal = Meal(name: name, type: type, day: .now, calories: kcal, protein: p, carbs: c, fat: g)
        meal.createdAt = createdAt
        return meal
    }

    // MARK: - DayLogSummary

    func testSummaryGroupsInDayOrderAndSkipsEmptyTypes() {
        let meals = [
            meal("Jantar", .dinner),
            meal("Café", .breakfast),
            meal("Lanche", .snack),
        ]
        let summary = DayLogSummary(meals: meals)
        XCTAssertEqual(summary.groups.map(\.type), [.breakfast, .snack, .dinner], "Sem almoço, na ordem do dia")
    }

    func testSummaryTotals() {
        let meals = [
            meal("A", .lunch, kcal: 500, p: 40, c: 50, g: 10),
            meal("B", .lunch, kcal: 300, p: 20, c: 30, g: 8),
            meal("C", .dinner, kcal: 200, p: 15, c: 5, g: 12),
        ]
        let summary = DayLogSummary(meals: meals)
        XCTAssertEqual(summary.total, Macros(calories: 1000, protein: 75, carbs: 85, fat: 30))
        XCTAssertEqual(summary.groups.first?.total.calories, 800)
    }

    func testEmptySummary() {
        let summary = DayLogSummary(meals: [])
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.total, .zero)
    }

    // MARK: - MealHistory (repetir refeição)

    func testHistoryKeepsMostRecentOfEachName() {
        let old = meal("Frango com arroz", .lunch, kcal: 500, createdAt: Date(timeIntervalSince1970: 1_000))
        let recent = meal("frango com arroz ", .dinner, kcal: 550, createdAt: Date(timeIntervalSince1970: 3_000))
        let other = meal("Iogurte", .snack, createdAt: Date(timeIntervalSince1970: 2_000))

        let history = MealHistory.uniqueRecent([old, other, recent])
        XCTAssertEqual(history.map(\.calories), [550, 100], "Mais recente primeiro; nome repetido (sem diferenciar maiúsculas/espaços) aparece uma vez")
    }

    // MARK: - MealFormViewModel

    func testNewMealFormStartsInvalid() {
        let form = MealFormViewModel(day: .now, type: .lunch)
        XCTAssertEqual(form.type, .lunch)
        XCTAssertFalse(form.isValid)
    }

    func testMealFormValidation() {
        let form = MealFormViewModel(day: .now)
        form.name = "  Omelete  "
        form.caloriesText = "350"
        form.proteinText = "24"
        form.carbsText = "3,5"
        form.fatText = "26"
        XCTAssertTrue(form.isValid)
        XCTAssertEqual(form.trimmedName, "Omelete")
        XCTAssertEqual(form.macros, Macros(calories: 350, protein: 24, carbs: 3.5, fat: 26))

        form.name = "   "
        XCTAssertFalse(form.isValid, "Nome só com espaços é inválido")

        form.name = "Omelete"
        form.fatText = ""
        XCTAssertFalse(form.isValid, "Campo vazio é inválido")

        form.fatText = "900"
        XCTAssertFalse(form.isValid, "Valor absurdo é inválido")

        form.fatText = "26"
        form.name = String(repeating: "a", count: MealFormViewModel.maxNameLength + 1)
        XCTAssertFalse(form.isValid, "Nome longo demais é inválido")
    }

    func testCaloriesFromMacros() {
        let form = MealFormViewModel(day: .now)
        form.proteinText = "30"
        form.carbsText = "50"
        form.fatText = "10"
        // 30×4 + 50×4 + 10×9 = 410
        XCTAssertEqual(form.caloriesFromMacros, 410)

        form.caloriesText = "400"
        XCTAssertFalse(form.caloriesLookInconsistent, "Diferença pequena é aceitável (rótulos arredondam)")

        form.caloriesText = "800"
        XCTAssertTrue(form.caloriesLookInconsistent)

        form.useCaloriesFromMacros()
        XCTAssertEqual(form.caloriesText, "410")
    }

    func testFillFromTemplateKeepsSelectedDay() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let form = MealFormViewModel(day: yesterday)
        form.fill(from: meal("Iogurte com whey", .snack, kcal: 260, p: 35, c: 18, g: 5))

        XCTAssertEqual(form.name, "Iogurte com whey")
        XCTAssertEqual(form.type, .snack)
        XCTAssertEqual(form.macros?.protein, 35)
        XCTAssertTrue(Calendar.current.isDate(form.day, inSameDayAs: yesterday), "Repetir usa o dia selecionado, não o da refeição original")
    }

    func testEditingFormLoadsMealValues() {
        let original = meal("Pão", .breakfast, kcal: 150.5, p: 5, c: 28, g: 2)
        let form = MealFormViewModel(editing: original)
        XCTAssertTrue(form.isEditing)
        XCTAssertEqual(form.macros?.calories, 150.5)
    }

    // MARK: - Meal

    func testMealDayIsStartOfDay() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: .now)!
        let meal = Meal(name: "X", type: .snack, day: afternoon, calories: 1, protein: 0, carbs: 0, fat: 0)
        XCTAssertEqual(meal.day, Calendar.current.startOfDay(for: afternoon))
    }

    // MARK: - DaySelection

    func testDaySelectionNavigation() {
        let selection = DaySelection()
        XCTAssertTrue(selection.isToday)
        XCTAssertEqual(selection.title, "Hoje")

        selection.move(byDays: -1)
        XCTAssertEqual(selection.title, "Ontem")
        XCTAssertFalse(selection.isToday)

        selection.move(byDays: 2)
        XCTAssertEqual(selection.title, "Amanhã")

        selection.goToToday()
        XCTAssertTrue(selection.isToday)
    }

    func testSuggestedMealType() {
        let calendar = Calendar.current
        func at(_ hour: Int) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now)! }
        XCTAssertEqual(MealType.suggested(for: at(7)), .breakfast)
        XCTAssertEqual(MealType.suggested(for: at(12)), .lunch)
        XCTAssertEqual(MealType.suggested(for: at(16)), .snack)
        XCTAssertEqual(MealType.suggested(for: at(20)), .dinner)
        XCTAssertEqual(MealType.suggested(for: at(2)), .dinner)
    }
}
