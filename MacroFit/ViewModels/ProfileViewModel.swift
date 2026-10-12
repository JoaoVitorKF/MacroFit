import Foundation
import Observation
import SwiftData

/// Estado do formulário de perfil (usado no onboarding e na edição do perfil).
/// Os campos numéricos ficam como texto para o usuário poder digitar livremente; a conversão e
/// a validação acontecem aqui, e o cálculo das metas é refeito a cada alteração.
@Observable
final class ProfileViewModel {
    var sex: BiologicalSex
    var ageText: String
    var weightText: String
    var heightText: String
    var activity: ActivityLevel
    var goal: Goal

    /// Cria o formulário vazio (onboarding) ou preenchido com um perfil existente (edição).
    init(profile: UserProfile? = nil) {
        if let profile {
            sex = profile.sex
            ageText = String(profile.age)
            weightText = NumberParser.format(profile.weightKg)
            heightText = NumberParser.format(profile.heightCm)
            activity = profile.activity
            goal = profile.goal
        } else {
            sex = .male
            ageText = ""
            weightText = ""
            heightText = ""
            activity = .moderate
            goal = .recomposition
        }
    }

    // MARK: - Validação e cálculo

    /// Dados prontos para o cálculo, ou `nil` se algum campo estiver vazio ou inválido.
    var input: NutritionInput? {
        guard let age = NumericField.age.value(from: ageText),
              let weight = NumericField.weight.value(from: weightText),
              let height = NumericField.height.value(from: heightText) else { return nil }

        return NutritionInput(
            sex: sex,
            age: Int(age),
            weightKg: weight,
            heightCm: height,
            activity: activity,
            goal: goal
        )
    }

    var isValid: Bool { input != nil }

    /// Metas calculadas em tempo real (atualizam enquanto o usuário digita).
    var targets: NutritionTargets? {
        input.map(NutritionCalculator.targets(for:))
    }

    // MARK: - Persistência

    /// Atualiza o perfil existente ou cria um novo. Retorna `false` se o formulário for inválido.
    @discardableResult
    func save(to existing: UserProfile?, in context: ModelContext) -> Bool {
        guard let input else { return false }

        if let profile = existing {
            let weightChanged = profile.weightKg != input.weightKg
            profile.sex = input.sex
            profile.age = input.age
            profile.weightKg = input.weightKg
            profile.heightCm = input.heightCm
            profile.activity = input.activity
            profile.goal = input.goal
            profile.updatedAt = .now
            // Peso alterado no formulário vira um registro de hoje no histórico
            if weightChanged {
                WeightStore.record(weightKg: input.weightKg, on: .now, profile: profile, in: context)
            }
        } else {
            context.insert(UserProfile(
                sex: input.sex,
                age: input.age,
                weightKg: input.weightKg,
                heightCm: input.heightCm,
                activity: input.activity,
                goal: input.goal
            ))
            // Primeiro ponto do histórico de peso
            context.insert(WeightEntry(weightKg: input.weightKg, day: .now))
        }
        try? context.save()
        return true
    }
}
