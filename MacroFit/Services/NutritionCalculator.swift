import Foundation

/// Dados necessários para calcular as metas. Independente do SwiftData para facilitar os testes.
struct NutritionInput: Equatable {
    var sex: BiologicalSex
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var activity: ActivityLevel
    var goal: Goal
}

/// Resultado completo do cálculo, pronto para exibir na tela.
struct NutritionTargets: Equatable {
    /// Taxa metabólica basal (kcal/dia).
    let bmr: Double
    /// Gasto energético total (kcal/dia) = TMB × fator de atividade.
    let tdee: Double
    /// Meta de calorias após aplicar o objetivo e o piso mínimo.
    let calories: Double
    /// `true` quando a meta calculada ficou abaixo do mínimo e foi elevada até ele.
    let minimumApplied: Bool
    let protein: Double
    let carbs: Double
    let fat: Double
    /// `true` quando proteína + gordura sozinhas já passam da meta de calorias (carbo fica em 0).
    let macrosExceedCalories: Bool

    /// Diferença entre a meta e o TDEE: negativo = déficit, positivo = superávit.
    var calorieDelta: Double { calories - tdee }

    var macros: Macros {
        Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}

/// Todas as fórmulas do app. Funções puras: mesma entrada → mesma saída, sem estado.
enum NutritionCalculator {

    // MARK: - Constantes

    static let kcalPerGramProtein = 4.0
    static let kcalPerGramCarb = 4.0
    static let kcalPerGramFat = 9.0

    /// Proteína: 2,0 g por kg de peso corporal.
    static let proteinGramsPerKg = 2.0
    /// Gordura: 0,9 g por kg de peso corporal...
    static let fatGramsPerKg = 0.9
    /// ...mas nunca menos que 20% das calorias.
    static let minimumFatShare = 0.20

    /// Piso de calorias diárias por sexo.
    static func minimumCalories(for sex: BiologicalSex) -> Double {
        switch sex {
        case .male: 1500
        case .female: 1200
        }
    }

    // MARK: - Fórmulas

    /// TMB por Mifflin-St Jeor.
    /// - Homem: 10×peso + 6,25×altura − 5×idade + 5
    /// - Mulher: 10×peso + 6,25×altura − 5×idade − 161
    static func bmr(sex: BiologicalSex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Gasto total (TDEE) = TMB × fator de atividade.
    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.factor
    }

    /// Meta de calorias: TDEE ajustado pelo objetivo, respeitando o piso por sexo.
    static func targetCalories(
        tdee: Double,
        goal: Goal,
        sex: BiologicalSex
    ) -> (calories: Double, minimumApplied: Bool) {
        let adjusted = tdee * goal.calorieMultiplier
        let minimum = minimumCalories(for: sex)
        if adjusted < minimum {
            return (minimum, true)
        }
        return (adjusted, false)
    }

    /// Divide as calorias em macros:
    /// - Proteína: 2,0 g/kg
    /// - Gordura: o maior entre 0,9 g/kg e 20% das calorias
    /// - Carboidrato: o que sobrar, nunca negativo
    static func macros(
        calories: Double,
        weightKg: Double
    ) -> (protein: Double, carbs: Double, fat: Double, exceedsCalories: Bool) {
        let protein = weightKg * proteinGramsPerKg

        let fatByWeight = weightKg * fatGramsPerKg
        let fatByShare = calories * minimumFatShare / kcalPerGramFat
        let fat = max(fatByWeight, fatByShare)

        let remainingKcal = calories - protein * kcalPerGramProtein - fat * kcalPerGramFat
        let carbs = max(0, remainingKcal / kcalPerGramCarb)

        return (protein, carbs, fat, remainingKcal < 0)
    }

    /// Faz o cálculo completo a partir dos dados do perfil.
    static func targets(for input: NutritionInput) -> NutritionTargets {
        let bmr = bmr(sex: input.sex, weightKg: input.weightKg, heightCm: input.heightCm, age: input.age)
        let tdee = tdee(bmr: bmr, activity: input.activity)
        let target = targetCalories(tdee: tdee, goal: input.goal, sex: input.sex)
        let split = macros(calories: target.calories, weightKg: input.weightKg)

        return NutritionTargets(
            bmr: bmr,
            tdee: tdee,
            calories: target.calories,
            minimumApplied: target.minimumApplied,
            protein: split.protein,
            carbs: split.carbs,
            fat: split.fat,
            macrosExceedCalories: split.exceedsCalories
        )
    }
}
