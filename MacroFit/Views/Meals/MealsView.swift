import SwiftData
import SwiftUI

/// Aba Refeições: lista do dia agrupada por tipo, com adicionar, editar e apagar.
struct MealsView: View {
    @Environment(DaySelection.self) private var selection
    @Environment(\.modelContext) private var context
    @State private var sheet: MealSheet?

    var body: some View {
        NavigationStack {
            DayMealsReader(day: selection.day) { meals in
                mealList(DayLogSummary(meals: meals))
            }
            .navigationTitle("Refeições")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sheet = .new(day: selection.day)
                    } label: {
                        Label("Adicionar refeição", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                MealFormView(sheet: sheet)
            }
            #if DEBUG
            .onAppear {
                if DemoData.opensMealForm { sheet = .new(day: selection.day) }
            }
            #endif
        }
    }

    @ViewBuilder
    private func mealList(_ summary: DayLogSummary) -> some View {
        List {
            Section {
                DaySelector()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if summary.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Nenhuma refeição", systemImage: "fork.knife")
                    } description: {
                        Text("Registre o que você comeu \(selection.isToday ? "hoje" : "neste dia").")
                    } actions: {
                        Button("Adicionar refeição") {
                            sheet = .new(day: selection.day)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color.accentForeground)
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    HStack {
                        Text("Total do dia")
                            .font(.headline)
                        Spacer()
                        Text("\(summary.total.calories.kcalText) kcal")
                            .font(.headline.monospacedDigit())
                    }
                    MacroLine(macros: summary.total)
                }

                ForEach(summary.groups) { group in
                    Section {
                        ForEach(group.meals) { meal in
                            Button {
                                sheet = .edit(meal)
                            } label: {
                                MealRow(meal: meal)
                            }
                            .foregroundStyle(.primary)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(meal)
                                } label: {
                                    Label("Apagar", systemImage: "trash")
                                }
                                Button {
                                    sheet = .edit(meal)
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } header: {
                        HStack {
                            Label(group.type.displayName, systemImage: group.type.symbol)
                            Spacer()
                            Text("\(group.total.calories.kcalText) kcal")
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .animation(.default, value: summary.total)
    }

    private func delete(_ meal: Meal) {
        context.delete(meal)
        try? context.save()
    }
}

#Preview {
    MealsView()
        .environment(DaySelection())
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
