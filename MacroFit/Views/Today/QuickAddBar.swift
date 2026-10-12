import SwiftData
import SwiftUI

/// Faixa "Adicionar rápido" da tela Hoje: as refeições mais frequentes, adicionadas com um toque.
/// Segurar um atalho abre o menu de porção (½, 1½, 2) e "editar antes de adicionar".
struct QuickAddBar: View {
    /// Busca as 300 refeições mais recentes — base para descobrir as frequentes.
    private static var recentMeals: FetchDescriptor<Meal> {
        var descriptor = FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 300
        return descriptor
    }

    @Query(QuickAddBar.recentMeals) private var meals: [Meal]

    /// Adicionar direto (refeição de referência e porção).
    let onAdd: (Meal, Portion) -> Void
    /// Abrir o formulário já preenchido, para ajustar antes de salvar.
    let onCustomize: (Meal) -> Void

    private var options: [Meal] { MealHistory.frequent(meals, limit: 8) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Adicionar rápido", systemImage: "bolt.fill")
                    .font(.headline)
                if !options.isEmpty {
                    Text("Toque para adicionar · segure para escolher a porção")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if options.isEmpty {
                Text("As refeições que você registrar aparecem aqui para adicionar de novo com um toque.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: QuickAddChip.spacing) {
                        ForEach(options) { meal in
                            QuickAddChip(meal: meal) { onAdd(meal, .one) }
                                .contextMenu {
                                    ForEach([Portion.half, .oneAndHalf, .double]) { portion in
                                        Button {
                                            onAdd(meal, portion)
                                        } label: {
                                            Label(
                                                "Adicionar \(portion.longLabel.lowercased()) (\(meal.macros.scaled(by: portion.rawValue).calories.kcalText) kcal)",
                                                systemImage: "plus"
                                            )
                                        }
                                    }
                                    Divider()
                                    Button {
                                        onCustomize(meal)
                                    } label: {
                                        Label("Editar antes de adicionar", systemImage: "pencil")
                                    }
                                }
                        }
                    }
                }
                // A rolagem vai de borda a borda do card (e é cortada nela, sem vazar para a tela),
                // com o primeiro atalho alinhado ao título
                .padding(.horizontal, -CardModifier.padding)
                .contentMargins(.horizontal, CardModifier.padding, for: .scrollContent)
                // Rolagem livre: com encaixe (.viewAligned), arrastes curtos voltavam ao lugar e
                // parecia que a faixa não rolava
            }
        }
        .card()
    }
}

/// Um atalho: nome (até 2 linhas), calorias e proteína, com "+" para deixar claro que adiciona.
/// Todos têm o mesmo tamanho, independente do nome; a largura deixa o terceiro aparecendo
/// na borda, indicando que dá para rolar.
private struct QuickAddChip: View {
    static let width: CGFloat = 130
    static let spacing: CGFloat = 10

    let meal: Meal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Nome com a largura toda do atalho
                Text(meal.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    // Sempre reserva 2 linhas: atalhos com nome curto ficam da mesma altura
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    Text("\(meal.calories.kcalText) kcal · P \(meal.protein.gramsText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .frame(width: Self.width, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adicionar \(meal.name), \(meal.calories.kcalText) kcal")
        .accessibilityIdentifier("atalho-\(meal.name)")
    }
}

/// Aviso temporário depois de uma adição rápida, com "Desfazer".
struct UndoToast: View {
    let title: String
    let detail: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Desfazer", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }
}
