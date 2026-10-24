import SwiftData
import SwiftUI

/// Card "Dica do momento" da tela Hoje. Busca o histórico para sugerir refeições
/// e, quando há sugestão, mostra o botão "Adicionar" (adição rápida, com Desfazer).
struct TipCard: View {
    private static var recentMeals: FetchDescriptor<Meal> {
        var descriptor = FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 300
        return descriptor
    }

    @Query(TipCard.recentMeals) private var history: [Meal]

    let consumed: Macros
    let targets: NutritionTargets
    let mealCount: Int
    let onAdd: (Meal) -> Void

    private var tip: DailyTip {
        DailyCoach.tip(
            consumed: consumed,
            targets: targets,
            mealCount: mealCount,
            hour: Calendar.current.component(.hour, from: .now),
            history: history
        )
    }

    private func color(for tone: DailyTip.Tone) -> Color {
        switch tone {
        case .info: .accentColor
        case .success: .green
        case .warning: .orange
        }
    }

    var body: some View {
        let tip = tip
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.symbol)
                .font(.title3)
                .foregroundStyle(color(for: tip.tone))
                .frame(width: 32, height: 32)
                .background(color(for: tip.tone).opacity(0.15), in: Circle())
                .symbolEffect(.bounce, value: tip.title)

            VStack(alignment: .leading, spacing: 6) {
                Text(tip.title)
                    .font(.headline)
                Text(tip.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let meal = tip.suggestion {
                    Button {
                        onAdd(meal)
                    } label: {
                        Label("Adicionar \(meal.name)", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.accentForeground)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .padding(.top, 2)
                    .accessibilityIdentifier("dica-adicionar")
                }
            }
            Spacer(minLength: 0)
        }
        .card()
        .animation(.default, value: tip)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dica-do-dia")
    }
}
