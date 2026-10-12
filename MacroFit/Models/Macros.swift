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

extension Macros {
    /// Multiplica todos os valores (ex.: meia porção = 0,5), arredondando para 1 casa decimal.
    func scaled(by factor: Double) -> Macros {
        func round1(_ value: Double) -> Double { (value * factor * 10).rounded() / 10 }
        return Macros(calories: round1(calories), protein: round1(protein), carbs: round1(carbs), fat: round1(fat))
    }
}

/// Tamanho da porção em relação à refeição original.
enum Portion: Double, CaseIterable, Identifiable {
    case half = 0.5
    case one = 1
    case oneAndHalf = 1.5
    case double = 2

    var id: Double { rawValue }

    /// Rótulo curto para o seletor: "½×", "1×", "1½×", "2×".
    var shortLabel: String {
        switch self {
        case .half: "½×"
        case .one: "1×"
        case .oneAndHalf: "1½×"
        case .double: "2×"
        }
    }

    /// Rótulo por extenso para menus: "Meia porção", "2 porções"…
    var longLabel: String {
        switch self {
        case .half: "Meia porção"
        case .one: "1 porção"
        case .oneAndHalf: "1 porção e meia"
        case .double: "2 porções"
        }
    }
}

extension Sequence where Element == Macros {
    /// Soma todos os valores (ex.: total consumido no dia).
    func total() -> Macros {
        reduce(.zero, +)
    }
}
