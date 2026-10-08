import SwiftData
import SwiftUI

/// Busca no SwiftData as refeições de um dia e entrega para o conteúdo.
/// Usado pelas abas Hoje e Refeições; ao mudar o dia, a consulta é refeita.
struct DayMealsReader<Content: View>: View {
    @Query private var meals: [Meal]
    private let content: ([Meal]) -> Content

    init(day: Date, calendar: Calendar = .current, @ViewBuilder content: @escaping ([Meal]) -> Content) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        _meals = Query(
            filter: #Predicate<Meal> { $0.day >= start && $0.day < end },
            sort: \Meal.createdAt
        )
        self.content = content
    }

    var body: some View {
        content(meals)
    }
}
