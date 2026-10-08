import XCTest
@testable import MacroFit

/// Testes do NutritionCalculator. Os valores esperados foram calculados à mão (contas nos comentários).
final class NutritionCalculatorTests: XCTestCase {

    private let accuracy = 0.001

    // Perfis de referência
    private let man = NutritionInput(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .recomposition)
    private let woman = NutritionInput(sex: .female, age: 25, weightKg: 60, heightCm: 165, activity: .light, goal: .recomposition)

    private func with(_ input: NutritionInput, goal: Goal) -> NutritionInput {
        var copy = input
        copy.goal = goal
        return copy
    }

    // MARK: - TMB (Mifflin-St Jeor)

    func testBMRMale() {
        // 10×80 + 6,25×180 − 5×30 + 5 = 800 + 1125 − 150 + 5 = 1780
        XCTAssertEqual(NutritionCalculator.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 30), 1780, accuracy: accuracy)
    }

    func testBMRFemale() {
        // 10×60 + 6,25×165 − 5×25 − 161 = 600 + 1031,25 − 125 − 161 = 1345,25
        XCTAssertEqual(NutritionCalculator.bmr(sex: .female, weightKg: 60, heightCm: 165, age: 25), 1345.25, accuracy: accuracy)
    }

    func testBMRDifferenceBetweenSexesIs166() {
        // Mesmos dados: a única diferença entre as fórmulas é +5 vs −161
        let male = NutritionCalculator.bmr(sex: .male, weightKg: 70, heightCm: 170, age: 40)
        let female = NutritionCalculator.bmr(sex: .female, weightKg: 70, heightCm: 170, age: 40)
        XCTAssertEqual(male - female, 166, accuracy: accuracy)
    }

    // MARK: - TDEE

    func testActivityFactors() {
        XCTAssertEqual(ActivityLevel.sedentary.factor, 1.2)
        XCTAssertEqual(ActivityLevel.light.factor, 1.375)
        XCTAssertEqual(ActivityLevel.moderate.factor, 1.55)
        XCTAssertEqual(ActivityLevel.high.factor, 1.725)
        XCTAssertEqual(ActivityLevel.veryHigh.factor, 1.9)
    }

    func testTDEE() {
        // 1780 × 1,55 = 2759
        XCTAssertEqual(NutritionCalculator.tdee(bmr: 1780, activity: .moderate), 2759, accuracy: accuracy)
        // 1345,25 × 1,375 = 1849,71875
        XCTAssertEqual(NutritionCalculator.tdee(bmr: 1345.25, activity: .light), 1849.71875, accuracy: accuracy)
    }

    // MARK: - Homem: os 3 objetivos (TDEE = 2759)

    func testMaleRecomposition() {
        let t = NutritionCalculator.targets(for: man)
        XCTAssertEqual(t.bmr, 1780, accuracy: accuracy)
        XCTAssertEqual(t.tdee, 2759, accuracy: accuracy)
        // 2759 × 0,85 = 2345,15
        XCTAssertEqual(t.calories, 2345.15, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, -413.85, accuracy: accuracy)
        XCTAssertFalse(t.minimumApplied)
        // Proteína 2,0 × 80 = 160 g; gordura max(0,9 × 80 = 72; 20% → 52,1) = 72 g
        XCTAssertEqual(t.protein, 160, accuracy: accuracy)
        XCTAssertEqual(t.fat, 72, accuracy: accuracy)
        // Carbo (2345,15 − 640 − 648) / 4 = 264,2875
        XCTAssertEqual(t.carbs, 264.2875, accuracy: accuracy)
        XCTAssertFalse(t.macrosExceedCalories)
    }

    func testMaleLoseFat() {
        let t = NutritionCalculator.targets(for: with(man, goal: .loseFat))
        // 2759 × 0,80 = 2207,2
        XCTAssertEqual(t.calories, 2207.2, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, -551.8, accuracy: accuracy)
        // Carbo (2207,2 − 640 − 648) / 4 = 229,8
        XCTAssertEqual(t.carbs, 229.8, accuracy: accuracy)
        XCTAssertFalse(t.minimumApplied)
    }

    func testMaleGainMuscle() {
        let t = NutritionCalculator.targets(for: with(man, goal: .gainMuscle))
        // 2759 × 1,10 = 3034,9
        XCTAssertEqual(t.calories, 3034.9, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, 275.9, accuracy: accuracy)
        // 20% de 3034,9 / 9 = 67,4 g < 72 g → continua 72 g
        XCTAssertEqual(t.fat, 72, accuracy: accuracy)
        // Carbo (3034,9 − 640 − 648) / 4 = 436,725
        XCTAssertEqual(t.carbs, 436.725, accuracy: accuracy)
    }

    // MARK: - Mulher: os 3 objetivos (TDEE = 1849,71875)

    func testFemaleRecomposition() {
        let t = NutritionCalculator.targets(for: woman)
        XCTAssertEqual(t.bmr, 1345.25, accuracy: accuracy)
        // 1849,71875 × 0,85 = 1572,2609375
        XCTAssertEqual(t.calories, 1572.2609375, accuracy: accuracy)
        // Proteína 120 g; gordura max(54; 34,9) = 54 g
        XCTAssertEqual(t.protein, 120, accuracy: accuracy)
        XCTAssertEqual(t.fat, 54, accuracy: accuracy)
        // Carbo (1572,2609375 − 480 − 486) / 4 = 151,565234375
        XCTAssertEqual(t.carbs, 151.565234375, accuracy: accuracy)
        XCTAssertFalse(t.minimumApplied)
    }

    func testFemaleLoseFat() {
        let t = NutritionCalculator.targets(for: with(woman, goal: .loseFat))
        // 1849,71875 × 0,80 = 1479,775 (acima do piso de 1200)
        XCTAssertEqual(t.calories, 1479.775, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, -369.94375, accuracy: accuracy)
        XCTAssertEqual(t.carbs, 128.44375, accuracy: accuracy)
        XCTAssertFalse(t.minimumApplied)
    }

    func testFemaleGainMuscle() {
        let t = NutritionCalculator.targets(for: with(woman, goal: .gainMuscle))
        // 1849,71875 × 1,10 = 2034,690625
        XCTAssertEqual(t.calories, 2034.690625, accuracy: accuracy)
        XCTAssertEqual(t.carbs, 267.17265625, accuracy: accuracy)
        XCTAssertGreaterThan(t.calorieDelta, 0)
    }

    // MARK: - Piso mínimo de calorias

    func testMinimumCaloriesPerSex() {
        XCTAssertEqual(NutritionCalculator.minimumCalories(for: .male), 1500)
        XCTAssertEqual(NutritionCalculator.minimumCalories(for: .female), 1200)
    }

    func testMaleMinimumApplied() {
        // TMB = 450 + 937,5 − 400 + 5 = 992,5 → TDEE 1191 → −20% = 952,8 < 1500
        let input = NutritionInput(sex: .male, age: 80, weightKg: 45, heightCm: 150, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.tdee, 1191, accuracy: accuracy)
        XCTAssertEqual(t.calories, 1500, accuracy: accuracy)
        XCTAssertTrue(t.minimumApplied)
        // A diferença é sempre meta final − TDEE; aqui o piso vira superávit
        XCTAssertEqual(t.calorieDelta, 309, accuracy: accuracy)
    }

    func testFemaleMinimumApplied() {
        // TMB = 400 + 875 − 350 − 161 = 764 → TDEE 916,8 → −20% = 733,44 < 1200
        let input = NutritionInput(sex: .female, age: 70, weightKg: 40, heightCm: 140, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 1200, accuracy: accuracy)
        XCTAssertTrue(t.minimumApplied)
        // Macros sobre a meta de 1200: proteína 80 g, gordura 36 g, carbo (1200 − 320 − 324) / 4 = 139 g
        XCTAssertEqual(t.protein, 80, accuracy: accuracy)
        XCTAssertEqual(t.fat, 36, accuracy: accuracy)
        XCTAssertEqual(t.carbs, 139, accuracy: accuracy)
    }

    func testMinimumNotAppliedJustAbove() {
        // 1900 × 0,85 = 1615 ≥ 1500 → mantém
        let result = NutritionCalculator.targetCalories(tdee: 1900, goal: .recomposition, sex: .male)
        XCTAssertEqual(result.calories, 1615, accuracy: accuracy)
        XCTAssertFalse(result.minimumApplied)
    }

    func testMinimumAppliedJustBelow() {
        // 1800 × 0,80 = 1440 < 1500 → sobe para 1500
        let result = NutritionCalculator.targetCalories(tdee: 1800, goal: .loseFat, sex: .male)
        XCTAssertEqual(result.calories, 1500, accuracy: accuracy)
        XCTAssertTrue(result.minimumApplied)
    }

    func testFemaleFloorDoesNotApplyToMaleValue() {
        // 1500 × 0,85 = 1275: abaixo do piso masculino, mas acima do feminino
        XCTAssertTrue(NutritionCalculator.targetCalories(tdee: 1500, goal: .recomposition, sex: .male).minimumApplied)
        XCTAssertFalse(NutritionCalculator.targetCalories(tdee: 1500, goal: .recomposition, sex: .female).minimumApplied)
    }

    // MARK: - Regras dos macros

    func testFatMinimumShareWins() {
        // TMB = 600 + 1187,5 − 100 + 5 = 1692,5 → TDEE 3215,75 → +10% = 3537,325
        // Gordura por peso = 54 g; por 20% = 707,465 / 9 = 78,607 g → vale o maior
        let input = NutritionInput(sex: .male, age: 20, weightKg: 60, heightCm: 190, activity: .veryHigh, goal: .gainMuscle)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 3537.325, accuracy: accuracy)
        XCTAssertEqual(t.fat, 3537.325 * 0.2 / 9, accuracy: accuracy)
        XCTAssertEqual(t.fat * 9 / t.calories, 0.20, accuracy: accuracy)
        // Carbo (3537,325 − 480 − 707,465) / 4 = 587,465
        XCTAssertEqual(t.carbs, 587.465, accuracy: accuracy)
    }

    func testCarbsNeverNegative() {
        // TMB = 900 + 937,5 − 350 − 161 = 1326,5 → TDEE 1591,8 → −20% = 1273,44
        // Proteína 180 g (720 kcal) + gordura 81 g (729 kcal) = 1449 kcal > 1273,44
        let input = NutritionInput(sex: .female, age: 70, weightKg: 90, heightCm: 150, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 1273.44, accuracy: accuracy)
        XCTAssertEqual(t.carbs, 0)
        XCTAssertTrue(t.macrosExceedCalories)
    }

    func testMacrosAddUpToCalories() {
        // Quando não há excesso, P×4 + C×4 + G×9 deve fechar exatamente na meta
        for sex in BiologicalSex.allCases {
            for goal in Goal.allCases {
                for activity in ActivityLevel.allCases {
                    let input = NutritionInput(sex: sex, age: 35, weightKg: 75, heightCm: 175, activity: activity, goal: goal)
                    let t = NutritionCalculator.targets(for: input)
                    guard !t.macrosExceedCalories else { continue }
                    let kcal = t.protein * 4 + t.carbs * 4 + t.fat * 9
                    XCTAssertEqual(kcal, t.calories, accuracy: accuracy, "\(sex) \(goal) \(activity)")
                }
            }
        }
    }

    func testProfileUsesCalculator() {
        // O @Model UserProfile deve produzir o mesmo resultado do cálculo direto
        let profile = UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate)
        XCTAssertEqual(profile.goal, .recomposition, "Recomposição é o objetivo padrão")
        XCTAssertEqual(profile.targets, NutritionCalculator.targets(for: man))
    }
}
