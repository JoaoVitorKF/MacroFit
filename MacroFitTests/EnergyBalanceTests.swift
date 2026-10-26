import SwiftData
import XCTest
@testable import MacroFit

/// Gasto real pelos registros (balanço de energia). Contas à mão nos comentários.
/// Referência: perfil de referência (homem 18a, 97 kg, 175 cm, moderado) → fórmula 3.067,0625 kcal.
@MainActor
final class EnergyBalanceTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }()
    private lazy var today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 9))!
    private let formula = 3067.0625

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today))!
    }

    /// Uma refeição de `kcal` em cada dia indicado (dias atrás).
    private func meals(_ kcal: Double, days: some Sequence<Int>) -> [(day: Date, calories: Double)] {
        days.map { (day($0), kcal) }
    }

    /// Pesagens que caem `weeklyLoss` kg por semana a partir de 97 kg há 28 dias.
    private func weights(days: [Int], weeklyLoss: Double) -> [(day: Date, kg: Double)] {
        days.map { (day($0), 97 - weeklyLoss * Double(28 - $0) / 7) }
    }

    private func estimate(_ meals: [(day: Date, calories: Double)], _ weights: [(day: Date, kg: Double)]) -> EnergyBalance.Result {
        EnergyBalance.estimate(meals: meals, weights: weights, formulaTdee: formula, today: today, calendar: calendar)
    }

    // MARK: - Conta

    func testFullMonthMeasuresRealExpenditure() throws {
        // Comeu 2.300 kcal por dia nos 28 dias e perdeu 0,5 kg por semana
        // Gasto = 2300 + (0,5 / 7) × 7700 = 2300 + 550 = 2850 (a fórmula dizia 3.067)
        let result = estimate(meals(2300, days: 1...28), weights(days: [28, 21, 14, 7, 0], weeklyLoss: 0.5))
        let estimate = try XCTUnwrap(result.estimate)
        XCTAssertEqual(estimate.measuredTdee, 2850, accuracy: 0.01)
        XCTAssertEqual(estimate.weeklyTrendKg, -0.5, accuracy: 0.0001)
        XCTAssertEqual(estimate.averageIntake, 2300)
        XCTAssertEqual(estimate.loggedDays, 28)
        XCTAssertEqual(estimate.confidence, 1, "28 dias completos: vale só o medido")
        XCTAssertEqual(estimate.tdee, 2850, accuracy: 0.01)
        XCTAssertFalse(estimate.wasClamped)
    }

    func testHalfTheDataBlendsWithFormula() throws {
        // 14 dias registrados e pesagens cobrindo 14 dias → 50% medido + 50% fórmula
        // Peso estável e 2.500 kcal → medido 2.500 → (2500 + 3067,0625) / 2 = 2783,53125
        let stable = [(day(14), 97.0), (day(7), 97.0), (day(0), 97.0)]
        let estimate = try XCTUnwrap(estimate(meals(2500, days: 1...14), stable).estimate)
        XCTAssertEqual(estimate.confidence, 0.5)
        XCTAssertEqual(estimate.measuredTdee, 2500, accuracy: 0.01)
        XCTAssertEqual(estimate.tdee, 2783.53125, accuracy: 0.01)
    }

    func testTrendUsesAllWeighInsNotJustTheEnds() throws {
        // Uma pesagem alta no meio (água, sal) não deve virar a tendência inteira:
        // pontos (0; 97), (7; 96,5), (14; 97,5), (21; 95,5), (28; 95) → reta dos mínimos quadrados
        let points: [(x: Double, y: Double)] = [(0, 97), (7, 96.5), (14, 97.5), (21, 95.5), (28, 95)]
        let slope = try XCTUnwrap(EnergyBalance.trendSlope(points))
        // média x = 14, média y = 96,3; Sxy = (−14)(0,7)+(−7)(0,2)+0+(7)(−0,8)+(14)(−1,3) = −35
        // Sxx = 196 + 49 + 0 + 49 + 196 = 490 → −0,0714 kg/dia (= −0,5 kg/semana, mesmo com o 97,5 no meio)
        XCTAssertEqual(slope, -35.0 / 490, accuracy: 0.000_001)
        XCTAssertNil(EnergyBalance.trendSlope([(1, 80), (1, 81)]), "Tudo no mesmo dia: sem tendência")
    }

    // MARK: - Requisitos

    func testNeedsMoreDataReportsProgress() {
        let result = estimate(meals(2300, days: 1...10), weights(days: [9, 2], weeklyLoss: 0.5))
        XCTAssertEqual(result, .needsMoreData(loggedDays: 10, weighIns: 2, spanDays: 7))
    }

    func testTodayAndIncompleteDaysDoNotCount() {
        // Hoje (dia ainda aberto) e dias com menos de 800 kcal (registro esquecido) ficam de fora
        var log = meals(2300, days: 1...13)
        log += meals(500, days: 14...20)
        log += meals(4000, days: [0])
        let result = estimate(log, weights(days: [28, 14, 0], weeklyLoss: 0.5))
        XCTAssertEqual(result, .needsMoreData(loggedDays: 13, weighIns: 3, spanDays: 28))
    }

    func testSeveralMealsInADayAreSummed() throws {
        // 3 refeições de 600 = 1.800 no dia (passa dos 800, conta)
        let log = (1...14).flatMap { offset in Array(repeating: (day: day(offset), calories: 600.0), count: 3) }
        let estimate = try XCTUnwrap(estimate(log, weights(days: [14, 7, 0], weeklyLoss: 0)).estimate)
        XCTAssertEqual(estimate.averageIntake, 1800)
    }

    func testOldDataOutsideTheWindowIsIgnored() {
        let result = estimate(meals(2300, days: 29...60), weights(days: [40, 35, 30], weeklyLoss: 0.5))
        XCTAssertEqual(result, .needsMoreData(loggedDays: 0, weighIns: 0, spanDays: 0))
    }

    func testImplausibleValueIsClamped() throws {
        // Registrou só 1.000 kcal/dia com o peso parado → 1.000 kcal de gasto é implausível
        // (provavelmente faltou registrar). Limita a 75% da fórmula: 2300,296875
        let stable = [(day(28), 97.0), (day(14), 97.0), (day(0), 97.0)]
        let estimate = try XCTUnwrap(estimate(meals(1000, days: 1...28), stable).estimate)
        XCTAssertTrue(estimate.wasClamped)
        XCTAssertEqual(estimate.measuredTdee, formula * 0.75, accuracy: 0.01)
    }

    // MARK: - Metas e SwiftData

    func testMeasuredTdeeDrivesTheTargets() {
        // Mesmo perfil, mas com o gasto medido de 2.850: emagrecer moderado = 2850 − 800,25 = 2049,75
        var input = NutritionInput(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate, goal: .loseFat)
        input.measuredTdee = 2850
        let targets = NutritionCalculator.targets(for: input)
        XCTAssertEqual(targets.tdee, 2850)
        XCTAssertTrue(targets.tdeeIsMeasured)
        XCTAssertEqual(targets.calories, 2049.75, accuracy: 0.001)
    }

    func testStoreSavesOnProfileAndCanBeTurnedOff() throws {
        let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let profile = UserProfile(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate, goal: .loseFat)
        context.insert(profile)
        let now = Date.now
        for offset in 1...28 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: now)!
            context.insert(Meal(name: "Dia \(offset)", type: .lunch, day: date, calories: 2300, protein: 150, carbs: 250, fat: 70))
        }
        for offset in [28, 21, 14, 7, 0] {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: now)!
            context.insert(WeightEntry(weightKg: 97 - 0.5 * Double(28 - offset) / 7, day: date))
        }

        XCTAssertNil(profile.measuredTdee)
        let result = EnergyStore.refresh(profile, in: context, today: now)
        XCTAssertNotNil(result.estimate)
        XCTAssertEqual(try XCTUnwrap(profile.measuredTdee), 2850, accuracy: 1)
        XCTAssertTrue(profile.targets.tdeeIsMeasured)
        XCTAssertEqual(profile.targets.calories, 2850 - 800.25, accuracy: 1)

        // Desligado: volta à fórmula (3.067,0625 − 800,25)
        profile.usesMeasuredTdee = false
        XCTAssertFalse(profile.targets.tdeeIsMeasured)
        XCTAssertEqual(profile.targets.calories, 2266.8125, accuracy: 0.001)
    }

    func testStoreClearsWhenDataGetsOld() throws {
        let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserProfile(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate)
        profile.measuredTdee = 2800
        container.mainContext.insert(profile)
        XCTAssertEqual(EnergyStore.refresh(profile, in: container.mainContext), .needsMoreData(loggedDays: 0, weighIns: 0, spanDays: 0))
        XCTAssertNil(profile.measuredTdee, "Sem dados recentes, volta para a fórmula")
    }
}
