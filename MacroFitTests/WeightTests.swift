import SwiftData
import XCTest
@testable import MacroFit

/// Testes do histórico de peso: lógica pura (WeightLog) e gravação com SwiftData em memória (WeightStore).
final class WeightTests: XCTestCase {

    private let calendar = Calendar.current
    private let accuracy = 0.001

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: .now))!
    }

    private func point(_ daysAgo: Int, _ kg: Double) -> WeightPoint {
        WeightPoint(day: self.daysAgo(daysAgo), weightKg: kg)
    }

    // MARK: - WeightLog (puro)

    func testFilterByPeriod() {
        let points = [point(120, 85), point(60, 83), point(20, 81), point(0, 80)]
        XCTAssertEqual(WeightLog.filter(points, period: .month).map(\.weightKg), [81, 80])
        XCTAssertEqual(WeightLog.filter(points, period: .quarter).map(\.weightKg), [83, 81, 80])
        XCTAssertEqual(WeightLog.filter(points, period: .all).count, 4)
    }

    func testChange() {
        XCTAssertEqual(WeightLog.change([point(30, 82.5), point(10, 81), point(0, 80)])!, -2.5, accuracy: accuracy)
        XCTAssertNil(WeightLog.change([point(0, 80)]), "Com um só ponto não há variação")
        XCTAssertNil(WeightLog.change([]))
    }

    func testYDomainHasPadding() {
        let domain = WeightLog.yDomain([point(2, 79), point(1, 82), point(0, 80)])
        XCTAssertEqual(domain.lowerBound, 78, accuracy: accuracy)
        XCTAssertEqual(domain.upperBound, 83, accuracy: accuracy)
    }

    func testNearestPoint() {
        let points = [point(20, 81), point(10, 80.5), point(0, 80)]
        let nearest = WeightLog.nearest(to: daysAgo(8), in: points)
        XCTAssertEqual(nearest?.weightKg, 80.5)
    }

    func testSignedKgText() {
        XCTAssertEqual(0.0.signedKgText, "0 kg")
        XCTAssertEqual(0.04.signedKgText, "0 kg", "Arredonda para 1 casa")
        XCTAssertTrue((-1.25).signedKgText.hasSuffix(" kg"))
        XCTAssertTrue(0.4.signedKgText.hasPrefix("+"))
    }

    // MARK: - WeightStore (SwiftData em memória)

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema(MacroFitSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        profile = UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate)
        context.insert(profile)
        try context.save()
    }

    func testRecordTodayUpdatesProfileAndTargets() {
        let change = WeightStore.record(weightKg: 78, on: .now, profile: profile, in: context)

        XCTAssertEqual(profile.weightKg, 78)
        XCTAssertEqual(WeightStore.entries(in: context).count, 1)
        // Proteína 2 g/kg: 160 → 156; calorias: 2.345,15 → 2.318,8 (TMB −20 → TDEE −31 → meta −26,35)
        XCTAssertEqual(change?.before.protein ?? 0, 160, accuracy: accuracy)
        XCTAssertEqual(change?.after.protein ?? 0, 156, accuracy: accuracy)
        XCTAssertEqual(change?.after.calories ?? 0, 2318.8, accuracy: accuracy)
        XCTAssertEqual(change?.oldWeightKg, 80)
    }

    func testSameDayReplacesEntry() {
        WeightStore.record(weightKg: 79, on: .now, profile: profile, in: context)
        WeightStore.record(weightKg: 78.6, on: .now, profile: profile, in: context)

        let entries = WeightStore.entries(in: context)
        XCTAssertEqual(entries.count, 1, "Um registro por dia")
        XCTAssertEqual(entries.first?.weightKg, 78.6)
        XCTAssertEqual(profile.weightKg, 78.6)
    }

    func testOlderEntryDoesNotChangeProfile() {
        WeightStore.record(weightKg: 79, on: .now, profile: profile, in: context)
        let change = WeightStore.record(weightKg: 83, on: daysAgo(10), profile: profile, in: context)

        XCTAssertNil(change, "Registro antigo não é o mais recente; as metas não mudam")
        XCTAssertEqual(profile.weightKg, 79)
        XCTAssertEqual(WeightStore.entries(in: context).count, 2)
    }

    func testDeletingLatestFallsBackToPrevious() {
        WeightStore.record(weightKg: 81, on: daysAgo(5), profile: profile, in: context)
        WeightStore.record(weightKg: 79, on: .now, profile: profile, in: context)
        XCTAssertEqual(profile.weightKg, 79)

        let latest = WeightStore.entries(in: context).first!
        let change = WeightStore.delete(latest, profile: profile, in: context)

        XCTAssertEqual(profile.weightKg, 81)
        XCTAssertEqual(change?.newWeightKg, 81)
    }

    func testEnsureInitialEntryRunsOnce() {
        WeightStore.ensureInitialEntry(for: profile, in: context)
        WeightStore.ensureInitialEntry(for: profile, in: context)

        let entries = WeightStore.entries(in: context)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg, 80)
    }

    func testEditingProfileWeightRecordsEntry() {
        let form = ProfileViewModel(profile: profile)
        form.weightText = "77,5"
        XCTAssertTrue(form.save(to: profile, in: context))

        XCTAssertEqual(profile.weightKg, 77.5)
        XCTAssertEqual(WeightStore.entries(in: context).first?.weightKg, 77.5)
    }

    func testEditingOtherFieldsDoesNotRecordWeight() {
        let form = ProfileViewModel(profile: profile)
        form.ageText = "31"
        form.save(to: profile, in: context)

        XCTAssertTrue(WeightStore.entries(in: context).isEmpty)
    }

    func testOnboardingCreatesFirstEntry() throws {
        let fresh = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let freshContext = ModelContext(fresh)
        let form = ProfileViewModel()
        form.ageText = "30"
        form.weightText = "72,3"
        form.heightText = "175"
        XCTAssertTrue(form.save(to: nil, in: freshContext))

        XCTAssertEqual(WeightStore.entries(in: freshContext).map(\.weightKg), [72.3])
    }
}
