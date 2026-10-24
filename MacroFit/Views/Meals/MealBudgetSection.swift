import SwiftUI

/// Quadro "Quanto posso comer?" do formulário de refeição (modo por alimentos):
/// quanto sobra para esta refeição, botão para sugerir os gramas e quanto a refeição já usa disso.
/// O orçamento vem do `MealBudgetReader`.
struct MealBudgetSection: View {
    @Bindable var viewModel: MealFormViewModel
    let budget: Macros?
    @State private var suggestions = 0

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
                    .foregroundStyle(.accentForeground)
                    .buttonBorderShape(.capsule)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("sugerir-quantidades")
                }

                if let total = viewModel.itemsTotal, budget.calories > 0 {
                    MealUsageView(total: total, budget: budget)
                }
            } header: {
                Text("Quanto posso comer?")
            } footer: {
                Text(viewModel.items.isEmpty
                     ? "Escreva o que vai comer no campo de texto: os gramas que cabem aparecem sozinhos."
                     : "O que falta no dia é dividido entre esta refeição e as que ainda faltam (café 25%, almoço 35%, lanche 15%, jantar 25%). Os gramas sugeridos nunca passam das calorias. Alimentos com cadeado ficam como estão.")
            }
            .sensoryFeedback(.success, trigger: suggestions)
        }
    }
}
