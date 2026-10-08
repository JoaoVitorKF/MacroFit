import Foundation
import Observation
import SwiftData

/// Estado do formulário de refeição: criar, editar ou repetir uma refeição anterior.
@Observable
final class MealFormViewModel {
    var name: String
    var type: MealType
    var caloriesText: String
    var proteinText: String
    var carbsText: String
    var fatText: String

    /// Dia ao qual a refeição pertence.
    let day: Date
    /// Refeição sendo editada (`nil` ao criar).
    let editing: Meal?

    static let maxNameLength = 60

    /// Nova refeição no dia escolhido. Sem tipo informado, sugere um pela hora atual.
    init(day: Date, type: MealType? = nil) {
        self.day = day
        self.editing = nil
        name = ""
        self.type = type ?? MealType.suggested()
        caloriesText = ""
        proteinText = ""
        carbsText = ""
        fatText = ""
    }

    /// Edição de uma refeição existente.
    init(editing meal: Meal) {
        self.day = meal.day
        self.editing = meal
        name = meal.name
        type = meal.type
        caloriesText = NumberParser.format(meal.calories)
        proteinText = NumberParser.format(meal.protein)
        carbsText = NumberParser.format(meal.carbs)
        fatText = NumberParser.format(meal.fat)
    }

    var isEditing: Bool { editing != nil }

    // MARK: - Repetir refeição

    /// Preenche o formulário com os dados de uma refeição anterior (o dia continua sendo o selecionado).
    func fill(from template: Meal) {
        name = template.name
        type = template.type
        caloriesText = NumberParser.format(template.calories)
        proteinText = NumberParser.format(template.protein)
        carbsText = NumberParser.format(template.carbs)
        fatText = NumberParser.format(template.fat)
    }

    // MARK: - Validação

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nameError: String? {
        if trimmedName.isEmpty { return "Dê um nome à refeição." }
        if trimmedName.count > Self.maxNameLength { return "Use no máximo \(Self.maxNameLength) caracteres." }
        return nil
    }

    /// Valores validados, ou `nil` se algum campo estiver vazio ou fora da faixa.
    var macros: Macros? {
        guard let calories = NumericField.calories.value(from: caloriesText),
              let protein = NumericField.protein.value(from: proteinText),
              let carbs = NumericField.carbs.value(from: carbsText),
              let fat = NumericField.fat.value(from: fatText) else { return nil }
        return Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    var isValid: Bool { nameError == nil && macros != nil }

    /// Calorias estimadas pelos macros (P×4 + C×4 + G×9), quando os três estão preenchidos.
    /// Ajuda a conferir o rótulo do alimento ou a preencher as calorias.
    var caloriesFromMacros: Double? {
        guard let protein = NumericField.protein.value(from: proteinText),
              let carbs = NumericField.carbs.value(from: carbsText),
              let fat = NumericField.fat.value(from: fatText) else { return nil }
        return protein * NutritionCalculator.kcalPerGramProtein
            + carbs * NutritionCalculator.kcalPerGramCarb
            + fat * NutritionCalculator.kcalPerGramFat
    }

    /// `true` se as calorias digitadas diferem bastante (>15% e >20 kcal) do que os macros indicam.
    var caloriesLookInconsistent: Bool {
        guard let estimated = caloriesFromMacros,
              let typed = NumericField.calories.value(from: caloriesText) else { return false }
        let difference = abs(typed - estimated)
        return difference > 20 && difference > estimated * 0.15
    }

    func useCaloriesFromMacros() {
        guard let estimated = caloriesFromMacros else { return }
        caloriesText = NumberParser.format(estimated.rounded())
    }

    // MARK: - Persistência

    /// Cria ou atualiza a refeição. Retorna `false` se o formulário for inválido.
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard nameError == nil, let macros else { return false }

        if let meal = editing {
            meal.name = trimmedName
            meal.type = type
            meal.calories = macros.calories
            meal.protein = macros.protein
            meal.carbs = macros.carbs
            meal.fat = macros.fat
        } else {
            context.insert(Meal(
                name: trimmedName,
                type: type,
                day: day,
                calories: macros.calories,
                protein: macros.protein,
                carbs: macros.carbs,
                fat: macros.fat
            ))
        }
        try? context.save()
        return true
    }
}
