import Foundation
import SwiftData

/// Uma refeição registrada em um dia.
@Model
final class Meal {
    var name: String
    var typeRaw: String
    /// Início do dia (00:00) ao qual a refeição pertence. É o campo usado para filtrar por dia.
    var day: Date
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Momento em que foi registrada; usado para ordenar dentro do mesmo tipo.
    var createdAt: Date

    init(
        name: String,
        type: MealType,
        day: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        calendar: Calendar = .current
    ) {
        self.name = name
        self.typeRaw = type.rawValue
        self.day = calendar.startOfDay(for: day)
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.createdAt = .now
    }

    var type: MealType {
        get { MealType(rawValue: typeRaw) ?? .snack }
        set { typeRaw = newValue.rawValue }
    }

    /// Valores nutricionais desta refeição como `Macros`.
    var macros: Macros {
        Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }
}
