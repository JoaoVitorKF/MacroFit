import Foundation
import SwiftData

/// Perfil do usuário. O app trabalha com um único perfil salvo.
@Model
final class UserProfile {
    var sexRaw: String
    var age: Int
    var weightKg: Double
    var heightCm: Double
    var activityRaw: String
    var goalRaw: String
    /// Ritmo de perda (`WeightLossPace`). Opcional: perfis antigos não têm e usam o moderado.
    var paceRaw: String?
    /// Gasto pelos registros (`EnergyBalance`), atualizado pelo `EnergyStore`. `nil` = ainda sem dados.
    var measuredTdee: Double?
    /// `true` se o usuário desligou o gasto pelos registros (metas só pela fórmula). `nil` = ligado.
    var ignoresMeasuredTdee: Bool?
    /// Foto do perfil (JPEG quadrado, já reduzido por `ProfilePhoto.prepare`). `nil` = sem foto.
    /// Fica em arquivo à parte (`externalStorage`), fora da tabela do banco.
    @Attribute(.externalStorage) var photoData: Data?
    var updatedAt: Date

    init(
        sex: BiologicalSex,
        age: Int,
        weightKg: Double,
        heightCm: Double,
        activity: ActivityLevel,
        goal: Goal = .recomposition,
        pace: WeightLossPace = .moderate
    ) {
        self.sexRaw = sex.rawValue
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.paceRaw = pace.rawValue
        self.updatedAt = .now
    }

    // MARK: - Acesso tipado aos enums

    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .recomposition }
        set { goalRaw = newValue.rawValue }
    }

    var pace: WeightLossPace {
        get { paceRaw.flatMap(WeightLossPace.init(rawValue:)) ?? .moderate }
        set { paceRaw = newValue.rawValue }
    }

    // MARK: - Cálculo

    /// Dados de entrada para o `NutritionCalculator` (com o gasto pelos registros, se estiver ligado).
    var nutritionInput: NutritionInput {
        var input = formulaInput
        input.measuredTdee = usesMeasuredTdee ? measuredTdee : nil
        return input
    }

    /// Só a fórmula (TMB × atividade), sem o gasto pelos registros.
    var formulaInput: NutritionInput {
        NutritionInput(
            sex: sex,
            age: age,
            weightKg: weightKg,
            heightCm: heightCm,
            activity: activity,
            goal: goal,
            pace: pace
        )
    }

    var usesMeasuredTdee: Bool {
        get { ignoresMeasuredTdee != true }
        set { ignoresMeasuredTdee = !newValue }
    }

    /// Metas calculadas a partir dos dados atuais do perfil.
    var targets: NutritionTargets {
        NutritionCalculator.targets(for: nutritionInput)
    }
}
