import SwiftData
import SwiftUI

/// Lista de refeições já registradas (sem nomes repetidos) para reaproveitar no formulário.
struct RepeatMealPicker: View {
    /// Busca as 500 refeições mais recentes — suficiente para o histórico e leve para o app.
    private static var recentMeals: FetchDescriptor<Meal> {
        var descriptor = FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 500
        return descriptor
    }

    @Query(RepeatMealPicker.recentMeals) private var meals: [Meal]
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    let onSelect: (Meal) -> Void

    private var options: [Meal] {
        let unique = MealHistory.uniqueRecent(meals)
        let term = search.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return unique }
        return unique.filter { $0.name.localizedStandardContains(term) }
    }

    var body: some View {
        List(options) { meal in
            Button {
                onSelect(meal)
                dismiss()
            } label: {
                MealRow(meal: meal, showsType: true)
            }
            .foregroundStyle(.primary)
        }
        .overlay {
            if meals.isEmpty {
                ContentUnavailableView(
                    "Nenhuma refeição ainda",
                    systemImage: "fork.knife",
                    description: Text("As refeições que você registrar aparecem aqui para repetir depois.")
                )
            } else if options.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Buscar refeição")
        .navigationTitle("Repetir refeição")
        .navigationBarTitleDisplayMode(.inline)
    }
}
