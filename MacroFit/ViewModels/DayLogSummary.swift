import Foundation
import SwiftData

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

/// Adição rápida: cria uma cópia de uma refeição anterior no dia escolhido, com a porção desejada.
enum MealQuickAdd {
    @discardableResult
    static func add(_ template: Meal, portion: Portion = .one, on day: Date, in context: ModelContext) -> Meal {
        let macros = template.macros.scaled(by: portion.rawValue)
        let meal = Meal(
            name: template.name,
            type: template.type,
            day: day,
            calories: macros.calories,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat
        )
        context.insert(meal)
        try? context.save()
        return meal
    }

    /// Desfaz uma adição rápida.
    static func undo(_ meal: Meal, in context: ModelContext) {
        context.delete(meal)
        try? context.save()
    }
}

/// Lista de refeições anteriores para "repetir refeição", sem repetir nomes.
enum MealHistory {
    /// Chave para considerar duas refeições "a mesma": nome sem espaços nas pontas e sem diferenciar maiúsculas.
    static func key(for meal: Meal) -> String {
        meal.name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Refeições mais frequentes (para o registro rápido): agrupa pelo nome, ordena pela quantidade de vezes
    /// e, no empate, pela mais recente. Cada item é a ocorrência mais recente (valores mais atuais).
    static func frequent(_ meals: [Meal], limit: Int = 8) -> [Meal] {
        let groups = Dictionary(grouping: meals, by: key(for:))
        return groups.values
            .compactMap { group -> (count: Int, latest: Meal)? in
                guard let latest = group.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
                return (group.count, latest)
            }
            .sorted { lhs, rhs in
                lhs.count != rhs.count ? lhs.count > rhs.count : lhs.latest.createdAt > rhs.latest.createdAt
            }
            .prefix(limit)
            .map(\.latest)
    }

    /// Mantém só a ocorrência mais recente de cada nome (ignorando maiúsculas e espaços),
    /// ordenando da mais recente para a mais antiga.
    static func uniqueRecent(_ meals: [Meal]) -> [Meal] {
        var seen = Set<String>()
        return meals
            .sorted { $0.createdAt > $1.createdAt }
            .filter { meal in
                seen.insert(key(for: meal)).inserted
            }
    }
}
