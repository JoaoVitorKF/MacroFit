import Foundation

/// Dados necessários para calcular as metas. Independente do SwiftData para facilitar os testes.
struct NutritionInput: Equatable {
    var sex: BiologicalSex
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var activity: ActivityLevel
    var goal: Goal
    /// Ritmo de perda (só vale para `goal == .loseFat`).
    var pace: WeightLossPace = .moderate
    /// Gasto estimado pelos registros (`EnergyBalance`). Quando existe, substitui TMB × atividade.
    var measuredTdee: Double? = nil
}

/// Por que a meta de calorias não é a que o objetivo pediria.
enum CalorieLimit: Equatable {
    /// Ficou abaixo do mínimo por sexo (1500/1200) e subiu até ele.
    case sexMinimum
    /// Ficou abaixo da TMB e subiu até ela (não comer menos que o gasto em repouso).
    case bmr
    /// O ritmo pedia um déficit maior que o máximo diário; usamos o máximo.
    case maxDeficit
}

/// Resultado completo do cálculo, pronto para exibir na tela.
struct NutritionTargets: Equatable {
    /// Taxa metabólica basal (kcal/dia).
    let bmr: Double
    /// Gasto energético total (kcal/dia) usado nas metas: o medido pelos registros, se houver,
    /// ou TMB × fator de atividade.
    let tdee: Double
    /// `true` quando o `tdee` veio dos registros (`EnergyBalance`), não da fórmula.
    let tdeeIsMeasured: Bool
    /// Meta de calorias após aplicar o objetivo e os limites.
    let calories: Double
    /// Limite que mudou a meta, se houve (piso por sexo, TMB ou déficit máximo).
    let limit: CalorieLimit?
    let protein: Double
    let carbs: Double
    let fat: Double
    /// Peso usado para proteína e gordura: o atual ou, acima do IMC 25, o peso de referência.
    let macroWeightKg: Double
    /// `true` quando os macros usaram o peso de referência em vez do peso atual.
    let usesReferenceWeight: Bool
    /// `true` quando proteína + gordura sozinhas já passam da meta de calorias (carbo fica em 0).
    let macrosExceedCalories: Bool

    /// Diferença entre a meta e o TDEE: negativo = déficit, positivo = superávit.
    var calorieDelta: Double { calories - tdee }

    /// `true` quando a meta calculada ficou abaixo do mínimo por sexo e foi elevada até ele.
    var minimumApplied: Bool { limit == .sexMinimum }

    /// Variação de peso esperada por semana (kg), pela regra de ~7.700 kcal por kg.
    /// Negativo = perda. É uma estimativa: no começo a balança mexe mais (água e glicogênio)
    /// e, com o tempo, o gasto cai um pouco junto com o peso.
    var weeklyWeightChangeKg: Double {
        calorieDelta * 7 / NutritionCalculator.kcalPerKgBodyWeight
    }

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

    /// Proteína: 2,0 g por kg (do peso de referência, ver `referenceWeight`).
    static let proteinGramsPerKg = 2.0
    /// Gordura: 0,9 g por kg (do peso de referência)...
    static let fatGramsPerKg = 0.9
    /// ...mas nunca menos que 20% das calorias.
    static let minimumFatShare = 0.20

    /// IMC usado para o peso de referência dos macros.
    static let referenceBMI = 25.0

    /// Energia de 1 kg de peso perdido ou ganho (principalmente gordura): ~7.700 kcal.
    static let kcalPerKgBodyWeight = 7700.0
    /// Maior déficit diário que o app aceita: acima disso a perda de músculo e a fome pesam demais.
    static let maxDailyDeficit = 1000.0

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

    /// Déficit diário para perder `pace` do peso por semana: peso × % × 7.700 ÷ 7.
    /// Ex.: 97 kg a 0,75%/semana = 0,7275 kg × 7.700 ÷ 7 = 800,25 kcal/dia.
    static func paceDeficit(weightKg: Double, pace: WeightLossPace) -> Double {
        weightKg * pace.weeklyFraction * kcalPerKgBodyWeight / 7
    }

    /// Meta de calorias:
    /// - Recomposição e ganho de massa: TDEE × multiplicador do objetivo
    /// - Emagrecer: TDEE − déficit do ritmo, com no máximo `maxDailyDeficit` (1.000 kcal)
    /// - Piso: nunca abaixo do mínimo por sexo nem, para perder peso, abaixo da TMB
    static func targetCalories(
        tdee: Double,
        bmr: Double,
        goal: Goal,
        sex: BiologicalSex,
        weightKg: Double,
        pace: WeightLossPace
    ) -> (calories: Double, limit: CalorieLimit?) {
        var calories: Double
        var limit: CalorieLimit?
        if let multiplier = goal.tdeeMultiplier {
            calories = tdee * multiplier
        } else {
            let wanted = paceDeficit(weightKg: weightKg, pace: pace)
            if wanted > maxDailyDeficit { limit = .maxDeficit }
            calories = tdee - min(wanted, maxDailyDeficit)
        }

        // A TMB só é piso quando a meta é de déficit (no ganho de massa a meta já fica acima dela)
        let minimum = minimumCalories(for: sex)
        let floor = goal == .gainMuscle ? minimum : max(minimum, bmr)
        if calories < floor {
            return (floor, floor == minimum ? .sexMinimum : .bmr)
        }
        return (calories, limit)
    }

    /// Peso de referência para os macros: o menor entre o peso atual e o peso no IMC 25.
    /// Com sobrepeso, boa parte do peso extra é gordura, que não pede proteína; 2 g/kg do peso total
    /// superestima a meta. Ex.: 175 cm → 25 × 1,75² = 76,5625 kg.
    static func referenceWeight(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        return min(weightKg, referenceBMI * heightM * heightM)
    }

    /// Divide as calorias em macros (`weightKg` já é o peso de referência):
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
        let tdee = input.measuredTdee ?? tdee(bmr: bmr, activity: input.activity)
        let target = targetCalories(
            tdee: tdee, bmr: bmr, goal: input.goal, sex: input.sex, weightKg: input.weightKg, pace: input.pace
        )
        let macroWeight = referenceWeight(weightKg: input.weightKg, heightCm: input.heightCm)
        let split = macros(calories: target.calories, weightKg: macroWeight)

        return NutritionTargets(
            bmr: bmr,
            tdee: tdee,
            tdeeIsMeasured: input.measuredTdee != nil,
            calories: target.calories,
            limit: target.limit,
            protein: split.protein,
            carbs: split.carbs,
            fat: split.fat,
            macroWeightKg: macroWeight,
            usesReferenceWeight: macroWeight < input.weightKg,
            macrosExceedCalories: split.exceedsCalories
        )
    }
}
