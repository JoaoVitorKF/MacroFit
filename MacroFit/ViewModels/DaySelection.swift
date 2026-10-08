import Foundation
import Observation

/// Dia selecionado, compartilhado entre as abas Hoje e Refeições
/// (mudar o dia numa aba muda na outra também).
@Observable
final class DaySelection {
    /// Sempre o início do dia (00:00).
    private(set) var day: Date
    private let calendar: Calendar
    /// Qual era o "hoje" na última verificação; serve para detectar a virada da meia-noite.
    private var knownToday: Date

    init(day: Date = .now, calendar: Calendar = .current) {
        self.calendar = calendar
        self.day = calendar.startOfDay(for: day)
        self.knownToday = calendar.startOfDay(for: .now)
    }

    var isToday: Bool { calendar.isDateInToday(day) }

    func select(_ date: Date) {
        day = calendar.startOfDay(for: date)
    }

    func move(byDays offset: Int) {
        if let newDay = calendar.date(byAdding: .day, value: offset, to: day) {
            day = newDay
        }
    }

    func goToToday() {
        select(.now)
    }

    /// Se o app ficou aberto na virada do dia e o usuário estava vendo "hoje", acompanha o novo dia.
    func refreshIfDayChanged() {
        let today = calendar.startOfDay(for: .now)
        guard today != knownToday else { return }
        if day == knownToday {
            day = today
        }
        knownToday = today
    }

    /// Rótulo amigável: "Hoje", "Ontem", "Amanhã" ou a data por extenso ("ter., 5 de out.").
    var title: String {
        if calendar.isDateInToday(day) { return "Hoje" }
        if calendar.isDateInYesterday(day) { return "Ontem" }
        if calendar.isDateInTomorrow(day) { return "Amanhã" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Data completa para mostrar abaixo do título ("7 de outubro de 2026").
    var subtitle: String {
        day.formatted(date: .long, time: .omitted)
    }
}
