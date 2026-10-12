import Foundation
import SwiftData

/// Um alimento com valores nutricionais **por 100 g**: da tabela TACO ou cadastrado pelo usuário.
struct Food: Identifiable, Hashable, Codable {
    enum Source: Hashable, Codable {
        /// Número do alimento na TACO.
        case taco(Int)
        /// Alimento próprio (`CustomFood`).
        case custom(UUID)
    }

    let source: Source
    let name: String
    let category: String
    /// Calorias e macros em 100 g.
    let per100g: Macros

    var id: String {
        switch source {
        case .taco(let number): "taco-\(number)"
        case .custom(let uuid): "custom-\(uuid.uuidString)"
        }
    }

    var tacoId: Int? {
        if case .taco(let number) = source { return number }
        return nil
    }

    var isCustom: Bool { tacoId == nil }

    /// Calorias e macros de uma quantidade em gramas.
    func macros(grams: Double) -> Macros {
        per100g.scaled(by: grams / 100)
    }
}

/// Alimento cadastrado pelo usuário (ex.: whey, produto de marca), a partir do rótulo.
/// Os valores são guardados por 100 g, como na TACO, para tudo funcionar do mesmo jeito.
@Model
final class CustomFood {
    var uuid: UUID
    var name: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var createdAt: Date

    init(name: String, per100g: Macros) {
        self.uuid = UUID()
        self.name = name
        self.kcal = per100g.calories
        self.protein = per100g.protein
        self.carbs = per100g.carbs
        self.fat = per100g.fat
        self.createdAt = .now
    }

    var food: Food {
        Food(
            source: .custom(uuid),
            name: name,
            category: "Meus alimentos",
            per100g: Macros(calories: kcal, protein: protein, carbs: carbs, fat: fat)
        )
    }

    /// Converte os valores de um rótulo ("porção de 30 g tem 120 kcal…") para 100 g.
    static func per100g(fromPortion portion: Macros, grams: Double) -> Macros {
        guard grams > 0 else { return portion }
        return portion.scaled(by: 100 / grams)
    }
}
