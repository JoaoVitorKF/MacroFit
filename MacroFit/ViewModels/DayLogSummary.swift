import Foundation

/// Resumo de um dia: refeições agrupadas por tipo e totais. Lógica pura, sem SwiftData.
struct DayLogSummary {
    struct Group: Identifiable {
        let type: MealType
        let meals: [Meal]
        var id: MealType { type }
        var total: Macros { meals.map(\.macros).total() }
    }

    /// Grupos na ordem do dia (café → almoço → lanche → jantar), só os que têm refeições.
    let groups: [Group]
    /// Soma de tudo o que foi comido no dia.
    let total: Macros

    init(meals: [Meal]) {
        let byType = Dictionary(grouping: meals, by: \.type)
        groups = MealType.allCases.compactMap { type in
            guard let meals = byType[type], !meals.isEmpty else { return nil }
            return Group(type: type, meals: meals.sorted { $0.createdAt < $1.createdAt })
        }
        total = meals.map(\.macros).total()
    }

    var isEmpty: Bool { groups.isEmpty }
}

/// Lista de refeições anteriores para "repetir refeição", sem repetir nomes.
enum MealHistory {
    /// Mantém só a ocorrência mais recente de cada nome (ignorando maiúsculas e espaços),
    /// ordenando da mais recente para a mais antiga.
    static func uniqueRecent(_ meals: [Meal]) -> [Meal] {
        var seen = Set<String>()
        return meals
            .sorted { $0.createdAt > $1.createdAt }
            .filter { meal in
                let key = meal.name.trimmingCharacters(in: .whitespaces).lowercased()
                return seen.insert(key).inserted
            }
    }
}
