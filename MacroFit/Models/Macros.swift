import Foundation

/// Calorias e macronutrientes (em gramas). Usado tanto para metas quanto para somar refeições.
struct Macros: Equatable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    static let zero = Macros(calories: 0, protein: 0, carbs: 0, fat: 0)

    static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

extension Sequence where Element == Macros {
    /// Soma todos os valores (ex.: total consumido no dia).
    func total() -> Macros {
        reduce(.zero, +)
    }
}
