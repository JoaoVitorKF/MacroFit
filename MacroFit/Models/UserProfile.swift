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
    var updatedAt: Date

    init(
        sex: BiologicalSex,
        age: Int,
        weightKg: Double,
        heightCm: Double,
        activity: ActivityLevel,
        goal: Goal = .recomposition
    ) {
        self.sexRaw = sex.rawValue
        self.age = age
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
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

    // MARK: - Cálculo

    /// Dados de entrada para o `NutritionCalculator`.
    var nutritionInput: NutritionInput {
        NutritionInput(
            sex: sex,
            age: age,
            weightKg: weightKg,
            heightCm: heightCm,
            activity: activity,
            goal: goal
        )
    }

    /// Metas calculadas a partir dos dados atuais do perfil.
    var targets: NutritionTargets {
        NutritionCalculator.targets(for: nutritionInput)
    }
}
