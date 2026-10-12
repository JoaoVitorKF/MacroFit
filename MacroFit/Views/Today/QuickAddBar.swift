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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Adicionar rápido", systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
                if !options.isEmpty {
                    Text("Segure para mudar a porção")
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
                    HStack(spacing: 10) {
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
                .scrollClipDisabled()
            }
        }
        .card()
    }
}

/// Um atalho: nome, calorias e proteína, com "+" para deixar claro que adiciona.
private struct QuickAddChip: View {
    let meal: Meal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(meal.calories.kcalText) kcal · P \(meal.protein.gramsText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 200, alignment: .leading)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adicionar \(meal.name), \(meal.calories.kcalText) kcal")
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
