import SwiftData
import SwiftUI

/// Calcula quanto sobra para uma refeição (`MealPlanner.budget`) a partir do perfil e das outras refeições
/// do dia, e entrega o valor ao conteúdo. `nil` enquanto não houver perfil.
/// Usado pelo formulário de refeição e pelo "O que vou comer?".
struct MealBudgetReader<Content: View>: View {
    let type: MealType
    let editingID: PersistentIdentifier?
    @ViewBuilder let content: (Macros?) -> Content

    @Query(sort: \UserProfile.updatedAt) private var profiles: [UserProfile]
    @Query private var dayMeals: [Meal]

    init(day: Date, type: MealType, editing: Meal? = nil, calendar: Calendar = .current,
         @ViewBuilder content: @escaping (Macros?) -> Content) {
        self.type = type
        self.editingID = editing?.persistentModelID
        self.content = content
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        _dayMeals = Query(filter: #Predicate<Meal> { $0.day >= start && $0.day < end })
    }

    var body: some View {
        content(budget)
    }

    private var budget: Macros? {
        guard let targets = profiles.first?.targets else { return nil }
        // Ao editar, a própria refeição não conta como "outra"
        let others = dayMeals.filter { $0.persistentModelID != editingID }
        return MealPlanner.budget(
            targets: targets,
            consumedByOthers: others.map(\.macros).total(),
            loggedTypes: Set(others.map(\.type)),
            for: type
        )
    }
}

/// Quanto a refeição usa do que sobra para ela: barra, "X de Y kcal" e o aviso que mais ajuda.
struct MealUsageView: View {
    let total: Macros
    let budget: Macros

    var body: some View {
        let ratio = total.calories / budget.calories
        let isOver = ratio > 1.05
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Esta refeição")
                    .font(.subheadline)
                Spacer()
                Text("\(total.calories.kcalText) de \(budget.calories.kcalText) kcal")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(isOver ? .red : .primary)
            }
            ProgressView(value: min(ratio, 1))
                .tint(isOver ? .red : .accentColor)
            if isOver {
                Text("Passou \((total.calories - budget.calories).kcalText) kcal do que sobra para esta refeição.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if ratio < 0.85 && budget.fat - total.fat > 10 {
                // Alimentos magros não chegam na gordura da fatia: as calorias que sobram são dela
                Text("Sobram ~\((budget.calories - total.calories).kcalText) kcal, quase tudo de gordura (\((budget.fat - total.fat).gramsText)). Se quiser, inclua azeite, castanhas ou queijo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if total.protein < budget.protein * 0.8 {
                Text("Faltam \((budget.protein - total.protein).gramsText) de proteína para esta refeição.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("uso-refeicao")
    }
}
