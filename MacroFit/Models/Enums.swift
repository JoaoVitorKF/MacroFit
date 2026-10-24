import Foundation

// Os enums ficam fora dos @Model e são salvos no SwiftData como `rawValue` (String).
// Isso evita problemas de migração e permite usá-los em filtros (#Predicate) se precisar.

/// Sexo biológico — usado apenas na fórmula de Mifflin-St Jeor e no piso de calorias.
enum BiologicalSex: String, CaseIterable, Identifiable, Codable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: "Masculino"
        case .female: "Feminino"
        }
    }
}

/// Nível de atividade física e o fator multiplicador da TMB.
enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary
    case light
    case moderate
    case high
    case veryHigh

    var id: String { rawValue }

    /// Fator aplicado sobre a TMB para chegar ao gasto total (TDEE).
    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        case .veryHigh: 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentário"
        case .light: "Leve"
        case .moderate: "Moderado"
        case .high: "Alto"
        case .veryHigh: "Muito alto"
        }
    }

    /// Descrição curta para ajudar a escolher o nível certo.
    var detail: String {
        switch self {
        case .sedentary: "Pouco ou nenhum exercício"
        case .light: "Exercício leve 1–3x por semana"
        case .moderate: "Exercício moderado 3–5x por semana"
        case .high: "Exercício intenso 6–7x por semana"
        case .veryHigh: "Treino pesado diário ou trabalho físico"
        }
    }
}

/// Objetivo do usuário e o ajuste percentual sobre o TDEE.
enum Goal: String, CaseIterable, Identifiable, Codable {
    case recomposition
    case loseFat
    case gainMuscle

    var id: String { rawValue }

    /// Multiplicador aplicado sobre o TDEE (ex.: 0.85 = −15%).
    var calorieMultiplier: Double {
        switch self {
        case .recomposition: 0.85
        case .loseFat: 0.80
        case .gainMuscle: 1.10
        }
    }

    var displayName: String {
        switch self {
        case .recomposition: "Recomposição"
        case .loseFat: "Emagrecer"
        case .gainMuscle: "Ganhar massa"
        }
    }

    var detail: String {
        switch self {
        case .recomposition: "Ganhar músculo e perder gordura (−15%)"
        case .loseFat: "Foco em perder gordura (−20%)"
        case .gainMuscle: "Foco em ganhar massa (+10%)"
        }
    }

    var symbol: String {
        switch self {
        case .recomposition: "arrow.triangle.2.circlepath"
        case .loseFat: "flame"
        case .gainMuscle: "dumbbell"
        }
    }
}

/// Tipo de refeição, na ordem em que aparecem no dia.
enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case lunch
    case snack
    case dinner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Café da manhã"
        case .lunch: "Almoço"
        case .snack: "Lanche"
        case .dinner: "Jantar"
        }
    }

    /// Com artigo, para frases: "o café da manhã", "o almoço"…
    var withArticle: String {
        "o " + displayName.lowercased()
    }

    /// Com "no", para botões: "no café da manhã", "no almoço"…
    var withIn: String {
        "no " + displayName.lowercased()
    }

    /// Nome curto para seletores apertados: "Café", "Almoço"…
    var shortName: String {
        self == .breakfast ? "Café" : displayName
    }

    var symbol: String {
        switch self {
        case .breakfast: "cup.and.saucer"
        case .lunch: "fork.knife"
        case .snack: "carrot"
        case .dinner: "moon.stars"
        }
    }

    /// Sugere um tipo de refeição de acordo com a hora (usado como padrão no formulário).
    static func suggested(for date: Date = .now, calendar: Calendar = .current) -> MealType {
        switch calendar.component(.hour, from: date) {
        case 5..<11: .breakfast
        case 11..<15: .lunch
        case 15..<18: .snack
        default: .dinner
        }
    }
}
