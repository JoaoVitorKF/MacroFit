import Foundation
import SwiftData

/// Um registro de peso. Há no máximo um por dia (registrar de novo no mesmo dia substitui).
@Model
final class WeightEntry {
    /// Início do dia (00:00) do registro.
    var day: Date
    var weightKg: Double
    var createdAt: Date

    init(weightKg: Double, day: Date, calendar: Calendar = .current) {
        self.weightKg = weightKg
        self.day = calendar.startOfDay(for: day)
        self.createdAt = .now
    }
}

/// Todos os modelos salvos pelo app. Use esta lista ao criar qualquer `ModelContainer`
/// (app, modo demo, previews e testes) para nenhum modelo ficar de fora.
enum MacroFitSchema {
    static let models: [any PersistentModel.Type] = [UserProfile.self, Meal.self, WeightEntry.self, CustomFood.self]
}
