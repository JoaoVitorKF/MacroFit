import SwiftData
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

/// Testes do registro rápido: porção, frequentes e adição/desfazer.
final class QuickAddTests: XCTestCase {

    private func meal(_ name: String, kcal: Double = 100, p: Double = 10, c: Double = 10, g: Double = 2, at seconds: TimeInterval) -> Meal {
        let meal = Meal(name: name, type: .snack, day: .now, calories: kcal, protein: p, carbs: c, fat: g)
        meal.createdAt = Date(timeIntervalSince1970: seconds)
        return meal
    }

    func testScaledMacros() {
        let base = Macros(calories: 650, protein: 52, carbs: 70, fat: 14)
        XCTAssertEqual(base.scaled(by: 0.5), Macros(calories: 325, protein: 26, carbs: 35, fat: 7))
        XCTAssertEqual(base.scaled(by: 1.5), Macros(calories: 975, protein: 78, carbs: 105, fat: 21))
        // Arredonda para 1 casa: 33,3 × 0,5 = 16,65 → 16,7
        XCTAssertEqual(Macros(calories: 0, protein: 33.3, carbs: 0, fat: 0).scaled(by: 0.5).protein, 16.7, accuracy: 0.0001)
    }

    func testFrequentOrdersByCountThenRecency() {
        let meals = [
            meal("Iogurte", at: 100), meal("iogurte ", at: 200), meal("Iogurte", kcal: 260, at: 300),
            meal("Frango", at: 400), meal("Frango", at: 50),
            meal("Pão", at: 500),
            meal("Ovo", at: 450),
        ]
        let frequent = MealHistory.frequent(meals)
        XCTAssertEqual(frequent.map(\.name), ["Iogurte", "Frango", "Pão", "Ovo"], "3× > 2× > 1× (mais recente primeiro no empate)")
        XCTAssertEqual(frequent.first?.calories, 260, "Usa a ocorrência mais recente (valores atuais)")
        XCTAssertEqual(MealHistory.frequent(meals, limit: 2).count, 2)
    }

    func testFormPortionScalesFromTemplate() {
        let template = meal("Frango", kcal: 650, p: 52, c: 70, g: 14, at: 0)
        let form = MealFormViewModel(day: .now)
        XCTAssertNil(form.portionBase, "Refeição nova em branco não tem seletor de porção")

        form.fill(from: template)
        form.apply(.double)
        XCTAssertEqual(form.macros, Macros(calories: 1300, protein: 104, carbs: 140, fat: 28))

        form.apply(.half)
        XCTAssertEqual(form.macros?.calories, 325, "Sempre a partir da referência, não do valor anterior")
    }

    func testTemplateInitAppliesPortion() {
        let template = meal("Iogurte", kcal: 260, p: 35, c: 18, g: 5, at: 0)
        let form = MealFormViewModel(day: .now, template: template, portion: .oneAndHalf)
        XCTAssertFalse(form.isEditing)
        XCTAssertEqual(form.portion, .oneAndHalf)
        XCTAssertEqual(form.macros?.calories, 390)
    }

    func testQuickAddAndUndo() throws {
        let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let template = Meal(name: "Iogurte", type: .snack, day: yesterday, calories: 260, protein: 35, carbs: 18, fat: 5)
        context.insert(template)

        let added = MealQuickAdd.add(template, portion: .double, on: .now, in: context)
        XCTAssertEqual(added.calories, 520)
        XCTAssertEqual(added.type, .snack)
        XCTAssertTrue(Calendar.current.isDateInToday(added.day))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 2)

        MealQuickAdd.undo(added, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Meal>()), 1, "Desfazer apaga só a cópia")
    }
}
