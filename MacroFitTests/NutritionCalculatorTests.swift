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
        // Ritmo moderado: 80 × 0,75% = 0,6 kg/semana → 0,6 × 7700 / 7 = 660 kcal/dia → 2759 − 660 = 2099
        XCTAssertEqual(t.calories, 2099, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, -660, accuracy: accuracy)
        XCTAssertEqual(t.weeklyWeightChangeKg, -0.6, accuracy: accuracy)
        // Carbo (2099 − 640 − 648) / 4 = 202,75
        XCTAssertEqual(t.carbs, 202.75, accuracy: accuracy)
        XCTAssertNil(t.limit)
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
        // 60 × 0,75% = 0,45 kg/semana → 495 kcal/dia → 1849,71875 − 495 = 1354,71875 (acima da TMB 1345,25)
        XCTAssertEqual(t.calories, 1354.71875, accuracy: accuracy)
        XCTAssertEqual(t.calorieDelta, -495, accuracy: accuracy)
        // Carbo (1354,71875 − 480 − 486) / 4 = 97,1796875
        XCTAssertEqual(t.carbs, 97.1796875, accuracy: accuracy)
        XCTAssertNil(t.limit)
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
        // TMB = 450 + 937,5 − 400 + 5 = 992,5 → TDEE 1191 → − 371,25 (45 kg × 0,75%) = 819,75 < 1500
        let input = NutritionInput(sex: .male, age: 80, weightKg: 45, heightCm: 150, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.tdee, 1191, accuracy: accuracy)
        XCTAssertEqual(t.calories, 1500, accuracy: accuracy)
        XCTAssertTrue(t.minimumApplied)
        // A diferença é sempre meta final − TDEE; aqui o piso vira superávit
        XCTAssertEqual(t.calorieDelta, 309, accuracy: accuracy)
    }

    func testFemaleMinimumApplied() {
        // TMB = 400 + 875 − 350 − 161 = 764 → TDEE 916,8 → − 330 (40 kg × 0,75%) = 586,8 < 1200
        let input = NutritionInput(sex: .female, age: 70, weightKg: 40, heightCm: 140, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 1200, accuracy: accuracy)
        XCTAssertTrue(t.minimumApplied)
        // Macros sobre a meta de 1200: proteína 80 g, gordura 36 g, carbo (1200 − 320 − 324) / 4 = 139 g
        XCTAssertEqual(t.protein, 80, accuracy: accuracy)
        XCTAssertEqual(t.fat, 36, accuracy: accuracy)
        XCTAssertEqual(t.carbs, 139, accuracy: accuracy)
    }

    private func target(tdee: Double, bmr: Double = 1100, goal: Goal, sex: BiologicalSex = .male,
                        weightKg: Double = 70, pace: WeightLossPace = .moderate) -> (calories: Double, limit: CalorieLimit?) {
        NutritionCalculator.targetCalories(tdee: tdee, bmr: bmr, goal: goal, sex: sex, weightKg: weightKg, pace: pace)
    }

    func testMinimumNotAppliedJustAbove() {
        // 1900 × 0,85 = 1615 ≥ 1500 → mantém
        let result = target(tdee: 1900, goal: .recomposition)
        XCTAssertEqual(result.calories, 1615, accuracy: accuracy)
        XCTAssertNil(result.limit)
    }

    func testMinimumAppliedJustBelow() {
        // 1750 × 0,85 = 1487,5 < 1500 → sobe para 1500
        let result = target(tdee: 1750, goal: .recomposition)
        XCTAssertEqual(result.calories, 1500, accuracy: accuracy)
        XCTAssertEqual(result.limit, .sexMinimum)
    }

    func testFemaleFloorDoesNotApplyToMaleValue() {
        // 1500 × 0,85 = 1275: abaixo do piso masculino, mas acima do feminino (e da TMB de 1100)
        XCTAssertEqual(target(tdee: 1500, goal: .recomposition, sex: .male).limit, .sexMinimum)
        XCTAssertNil(target(tdee: 1500, goal: .recomposition, sex: .female).limit)
    }

    // MARK: - Ritmo de perda, déficit máximo e TMB como piso

    func testPaceDeficit() {
        // 97 kg: 0,5% = 0,485 kg/sem → 533,5 kcal/dia · 0,75% → 800,25 · 1% → 1067
        XCTAssertEqual(NutritionCalculator.paceDeficit(weightKg: 97, pace: .gentle), 533.5, accuracy: accuracy)
        XCTAssertEqual(NutritionCalculator.paceDeficit(weightKg: 97, pace: .moderate), 800.25, accuracy: accuracy)
        XCTAssertEqual(NutritionCalculator.paceDeficit(weightKg: 97, pace: .fast), 1067, accuracy: accuracy)
    }

    func testRealProfileModeratePace() {
        // Homem 18a, 97 kg, 175 cm, moderado: TMB = 970 + 1093,75 − 90 + 5 = 1978,75 → TDEE × 1,55 = 3067,0625
        // Antes (−20%): 2453,65 kcal. Agora, 0,75%/semana: 3067,0625 − 800,25 = 2266,8125
        let input = NutritionInput(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate, goal: .loseFat, pace: .moderate)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.bmr, 1978.75, accuracy: accuracy)
        XCTAssertEqual(t.calories, 2266.8125, accuracy: accuracy)
        XCTAssertEqual(t.weeklyWeightChangeKg, -0.7275, accuracy: accuracy)
        XCTAssertNil(t.limit)
    }

    func testFastPaceIsCappedAtMaxDeficit() {
        // 97 kg a 1%: pediria 1067 kcal/dia → limitado a 1000 → 3067,0625 − 1000 = 2067,0625 (acima da TMB)
        let input = NutritionInput(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate, goal: .loseFat, pace: .fast)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 2067.0625, accuracy: accuracy)
        XCTAssertEqual(t.limit, .maxDeficit)
        XCTAssertEqual(t.weeklyWeightChangeKg, -1000 * 7 / 7700, accuracy: accuracy)
    }

    func testBMRIsTheFloorWhenLosingWeight() {
        // Sedentário: TDEE 1978,75 × 1,2 = 2374,5 → − 1000 = 1374,5 < TMB 1978,75 → meta = TMB
        // O ritmo real cai para (2374,5 − 1978,75) × 7 / 7700 ≈ 0,36 kg/semana
        let input = NutritionInput(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .sedentary, goal: .loseFat, pace: .fast)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 1978.75, accuracy: accuracy)
        XCTAssertEqual(t.limit, .bmr)
        XCTAssertEqual(t.weeklyWeightChangeKg, -395.75 * 7 / 7700, accuracy: accuracy)
        XCTAssertFalse(t.minimumApplied, "O aviso do piso por sexo é outro")
    }

    func testGainMuscleIgnoresPaceAndBMRFloor() {
        let input = NutritionInput(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .gainMuscle, pace: .fast)
        XCTAssertEqual(NutritionCalculator.targets(for: input).calories, 3034.9, accuracy: accuracy)
    }

    func testRecompositionWeeklyChange() {
        // −413,85 kcal/dia × 7 / 7700 = −0,37623 kg/semana
        XCTAssertEqual(NutritionCalculator.targets(for: man).weeklyWeightChangeKg, -0.37623, accuracy: 0.0001)
    }

    func testOldProfileWithoutPaceUsesModerate() {
        let profile = UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .loseFat)
        profile.paceRaw = nil
        XCTAssertEqual(profile.pace, .moderate)
        XCTAssertEqual(profile.targets.calories, 2099, accuracy: accuracy)
    }

    func testPaceDetail() {
        XCTAssertEqual(WeightLossPace.moderate.detail, "0,75% do peso por semana")
        XCTAssertEqual(WeightLossPace.fast.detail, "1% do peso por semana")
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
        // TMB = 900 + 937,5 − 350 − 161 = 1326,5 → TDEE 1591,8 → − 742,5 = 849,3 < TMB → meta = 1326,5
        // Proteína 180 g (720 kcal) + gordura 81 g (729 kcal) = 1449 kcal > 1326,5
        let input = NutritionInput(sex: .female, age: 70, weightKg: 90, heightCm: 150, activity: .sedentary, goal: .loseFat)
        let t = NutritionCalculator.targets(for: input)
        XCTAssertEqual(t.calories, 1326.5, accuracy: accuracy)
        XCTAssertEqual(t.limit, .bmr)
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
