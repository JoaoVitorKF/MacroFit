import Foundation
import SwiftData

/// Um alimento dentro de uma refeição: quantos gramas e os valores por 100 g no momento do registro.
/// Os valores ficam copiados na refeição: se um alimento próprio for editado ou apagado depois,
/// as refeições antigas continuam com os números de quando foram registradas.
struct MealItem: Codable, Hashable, Identifiable {
    var id = UUID()
    /// `Food.id` de origem ("taco-3", "custom-…").
    var foodId: String
    var name: String
    var grams: Double
    var per100g: Macros

    init(food: Food, grams: Double) {
        self.foodId = food.id
        self.name = food.name
        self.grams = grams
        self.per100g = food.per100g
    }

    /// Calorias e macros desta quantidade.
    var macros: Macros { per100g.scaled(by: grams / 100) }

    /// Nome curto para títulos: "Arroz, tipo 1, cozido" → "Arroz";
    /// "Carne, bovina, patinho, …" → "Patinho" (o corte diz mais que "Carne").
    var shortName: String {
        let parts = name.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 3, parts[0] == "Carne" {
            return parts[2].prefix(1).uppercased() + parts[2].dropFirst()
        }
        return parts.first ?? name
    }
}

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
    /// Alimentos da refeição (JSON de `[MealItem]`). `nil` em refeições digitadas à mão
    /// ou registradas antes desta opção existir.
    var itemsData: Data?

    init(
        name: String,
        type: MealType,
        day: Date,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        items: [MealItem] = [],
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
        self.itemsData = items.isEmpty ? nil : try? JSONEncoder().encode(items)
    }

    /// Refeição montada por alimentos: os totais são a soma dos itens.
    convenience init(name: String, type: MealType, day: Date, items: [MealItem], calendar: Calendar = .current) {
        let total = items.map(\.macros).total()
        self.init(
            name: name, type: type, day: day,
            calories: total.calories, protein: total.protein, carbs: total.carbs, fat: total.fat,
            items: items, calendar: calendar
        )
    }

    var type: MealType {
        get { MealType(rawValue: typeRaw) ?? .snack }
        set { typeRaw = newValue.rawValue }
    }

    /// Valores nutricionais desta refeição como `Macros`.
    var macros: Macros {
        Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    var items: [MealItem] {
        get { itemsData.flatMap { try? JSONDecoder().decode([MealItem].self, from: $0) } ?? [] }
        set { itemsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }

    /// Troca os itens e recalcula os totais a partir deles.
    func setItems(_ newItems: [MealItem]) {
        items = newItems
        let total = newItems.map(\.macros).total()
        calories = total.calories
        protein = total.protein
        carbs = total.carbs
        fat = total.fat
    }

    /// "Arroz 200 g · Patinho 150 g" (vazio se a refeição foi digitada à mão).
    var itemsSummary: String {
        items.map { "\($0.shortName) \($0.grams.formatted(.number.precision(.fractionLength(0...1)))) g" }
            .joined(separator: " · ")
    }
}
