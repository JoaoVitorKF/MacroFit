import SwiftData
import SwiftUI

/// Quadro "Quanto posso comer?" do formulário de refeição (modo por alimentos):
/// quanto sobra para esta refeição, botão para sugerir os gramas e quanto a refeição já usa disso.
struct MealBudgetSection: View {
    @Bindable var viewModel: MealFormViewModel

    @Query(sort: \UserProfile.updatedAt) private var profiles: [UserProfile]
    @Query private var dayMeals: [Meal]
    @State private var suggestions = 0

    init(viewModel: MealFormViewModel, calendar: Calendar = .current) {
        self.viewModel = viewModel
        let start = calendar.startOfDay(for: viewModel.day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        _dayMeals = Query(filter: #Predicate<Meal> { $0.day >= start && $0.day < end })
    }

    /// Outras refeições do dia (ao editar, sem contar a própria).
    private var otherMeals: [Meal] {
        dayMeals.filter { $0.persistentModelID != viewModel.editing?.persistentModelID }
    }

    private var budget: Macros? {
        guard let targets = profiles.first?.targets else { return nil }
        return MealPlanner.budget(
            targets: targets,
            consumedByOthers: otherMeals.map(\.macros).total(),
            loggedTypes: Set(otherMeals.map(\.type)),
            for: viewModel.type
        )
    }

    var body: some View {
        if let budget {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(budget.calories < 50
                         ? "A meta de calorias de hoje já foi atingida."
                         : "Para \(viewModel.type.withArticle) sobram ~\(budget.calories.kcalText) kcal")
                        .font(.subheadline.weight(.semibold))
                    MacroLine(macros: budget)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("orcamento-refeicao")

                if !viewModel.items.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            viewModel.suggestPortions(budget: budget)
                        }
                        suggestions += 1
                    } label: {
                        Label("Sugerir quantidades", systemImage: "wand.and.stars")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.accentForeground)
                    .buttonBorderShape(.capsule)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("sugerir-quantidades")
                }

                if let total = viewModel.itemsTotal, budget.calories > 0 {
                    usage(total: total, budget: budget)
                }
            } header: {
                Text("Quanto posso comer?")
            } footer: {
                Text(viewModel.items.isEmpty
                     ? "Adicione os alimentos e toque em Sugerir quantidades para ver quantos gramas cabem."
                     : "O que falta no dia é dividido entre esta refeição e as que ainda faltam (café 25%, almoço 35%, lanche 15%, jantar 25%). Os gramas sugeridos nunca passam das calorias; ajuste à vontade.")
            }
            .sensoryFeedback(.success, trigger: suggestions)
        }
    }

    /// Barra: quanto desta refeição já usa do que sobra para ela.
    private func usage(total: Macros, budget: Macros) -> some View {
        let ratio = total.calories / budget.calories
        let isOver = ratio > 1.05
        return VStack(alignment: .leading, spacing: 6) {
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
