import SwiftData
import SwiftUI

/// Aba Hoje: anel de calorias, botão grande "+", adição rápida, barras de macros e resumo por refeição.
struct TodayView: View {
    let profile: UserProfile
    @Environment(DaySelection.self) private var selection
    @Environment(\.modelContext) private var context
    @State private var sheet: MealSheet?
    /// Última refeição adicionada pelo atalho (mostra o aviso com "Desfazer").
    @State private var quickAdded: Meal?
    @State private var toastTimer: Task<Void, Never>?
    /// Conta as adições rápidas para disparar a vibração de sucesso.
    @State private var quickAddCount = 0

    var body: some View {
        NavigationStack {
            DayMealsReader(day: selection.day) { meals in
                content(DayLogSummary(meals: meals), targets: profile.targets)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resumo")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet) { sheet in
                MealFormView(sheet: sheet)
            }
            .overlay(alignment: .bottom) {
                if let meal = quickAdded {
                    UndoToast(
                        title: meal.name,
                        detail: "Adicionado · \(meal.calories.kcalText) kcal · \(meal.type.displayName)"
                    ) {
                        undoQuickAdd(meal)
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sensoryFeedback(.success, trigger: quickAddCount)
        }
    }

    // MARK: - Adição rápida

    private func quickAdd(_ template: Meal, portion: Portion) {
        let meal = MealQuickAdd.add(template, portion: portion, on: selection.day, in: context)
        quickAddCount += 1
        withAnimation(.spring(duration: 0.4)) { quickAdded = meal }

        // O aviso some sozinho depois de 4 segundos
        toastTimer?.cancel()
        toastTimer = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation { quickAdded = nil }
        }
    }

    private func undoQuickAdd(_ meal: Meal) {
        toastTimer?.cancel()
        withAnimation { quickAdded = nil }
        MealQuickAdd.undo(meal, in: context)
    }

    private func content(_ summary: DayLogSummary, targets: NutritionTargets) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                DaySelector()
                    .card()

                CalorieRingView(consumed: summary.total.calories, goal: targets.calories)
                    .card()

                addButton

                QuickAddBar(
                    onAdd: { meal, portion in quickAdd(meal, portion: portion) },
                    onCustomize: { meal in sheet = .fromTemplate(meal, day: selection.day, portion: .one) }
                )

                VStack(spacing: 18) {
                    MacroBarView(nutrient: .protein, consumed: summary.total.protein, goal: targets.protein)
                    MacroBarView(nutrient: .carbs, consumed: summary.total.carbs, goal: targets.carbs)
                    MacroBarView(nutrient: .fat, consumed: summary.total.fat, goal: targets.fat)
                }
                .card()

                MealTypesCard(summary: summary) { type in
                    sheet = .new(day: selection.day, type: type)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    /// Botão grande "+" para adicionar refeição. Fica no fluxo da tela (não flutua),
    /// para não cobrir os cards; logo abaixo do anel, ao alcance sem rolar.
    private var addButton: some View {
        Button {
            sheet = .new(day: selection.day)
        } label: {
            Label("Adicionar refeição", systemImage: "plus.circle.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .foregroundStyle(Color.accentForeground)
    }
}

/// Calorias por tipo de refeição. Tocar num tipo abre o formulário já com aquele tipo.
private struct MealTypesCard: View {
    let summary: DayLogSummary
    let onAdd: (MealType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Refeições")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(MealType.allCases) { type in
                let group = summary.groups.first { $0.type == type }
                Button {
                    onAdd(type)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.symbol)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .foregroundStyle(.primary)
                            if let group {
                                Text(group.meals.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if let group {
                            Text("\(group.total.calories.kcalText) kcal")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Adicionar \(type.displayName.lowercased())")

                if type != MealType.allCases.last {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .card()
    }
}

#Preview {
    TodayView(profile: UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate))
        .environment(DaySelection())
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
