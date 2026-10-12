import Foundation
import SwiftData

// MARK: - Lógica pura do histórico de peso (sem SwiftData, fácil de testar)

/// Um ponto do gráfico de peso.
struct WeightPoint: Equatable, Identifiable {
    let day: Date
    let weightKg: Double
    var id: Date { day }
}

/// Período mostrado no gráfico.
enum WeightPeriod: String, CaseIterable, Identifiable {
    case month
    case quarter
    case all

    var id: String { rawValue }

    /// Quantidade de dias para trás, ou `nil` para todo o histórico.
    var days: Int? {
        switch self {
        case .month: 30
        case .quarter: 90
        case .all: nil
        }
    }

    var displayName: String {
        switch self {
        case .month: "30 dias"
        case .quarter: "90 dias"
        case .all: "Tudo"
        }
    }
}

enum WeightLog {
    /// Pontos em ordem cronológica (do mais antigo para o mais recente).
    static func points(from entries: [WeightEntry]) -> [WeightPoint] {
        entries
            .map { WeightPoint(day: $0.day, weightKg: $0.weightKg) }
            .sorted { $0.day < $1.day }
    }

    /// Só os pontos dentro do período (contando a partir do início de hoje).
    static func filter(_ points: [WeightPoint], period: WeightPeriod, now: Date = .now, calendar: Calendar = .current) -> [WeightPoint] {
        guard let days = period.days,
              let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else {
            return points
        }
        return points.filter { $0.day >= start }
    }

    /// Variação entre o primeiro e o último ponto (negativo = perdeu peso). Precisa de 2 pontos ou mais.
    static func change(_ points: [WeightPoint]) -> Double? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        return last.weightKg - first.weightKg
    }

    /// Faixa do eixo Y com folga, para a linha não encostar nas bordas do gráfico.
    static func yDomain(_ points: [WeightPoint], padding: Double = 1) -> ClosedRange<Double> {
        guard let min = points.map(\.weightKg).min(), let max = points.map(\.weightKg).max() else {
            return 0...1
        }
        return (min - padding)...(max + padding)
    }

    /// Ponto mais próximo de uma data (usado ao tocar/arrastar no gráfico).
    static func nearest(to date: Date, in points: [WeightPoint]) -> WeightPoint? {
        points.min { abs($0.day.timeIntervalSince(date)) < abs($1.day.timeIntervalSince(date)) }
    }
}

extension Double {
    /// Peso para exibir: "79,5 kg".
    var kgText: String {
        formatted(.number.precision(.fractionLength(0...1))) + " kg"
    }

    /// Variação de peso com sinal: "−1,2 kg", "+0,4 kg" ou "0 kg".
    var signedKgText: String {
        let rounded = (self * 10).rounded() / 10
        if rounded == 0 { return "0 kg" }
        return rounded.formatted(.number.precision(.fractionLength(0...1)).sign(strategy: .always())) + " kg"
    }
}

// MARK: - Gravação (SwiftData)

/// Como as metas mudaram por causa de um novo peso — para avisar o usuário.
struct GoalChange: Equatable {
    let oldWeightKg: Double
    let newWeightKg: Double
    let before: NutritionTargets
    let after: NutritionTargets
}

/// Grava e apaga registros de peso mantendo a regra principal:
/// **o peso do perfil é sempre o do registro mais recente**, e as metas acompanham.
enum WeightStore {

    static func entries(in context: ModelContext) -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Registra o peso de um dia (substitui se já houver registro nesse dia).
    /// Retorna a mudança nas metas, se o registro passou a ser o mais recente e mudou o peso do perfil.
    @discardableResult
    static func record(
        weightKg: Double,
        on date: Date,
        profile: UserProfile,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> GoalChange? {
        let day = calendar.startOfDay(for: date)
        if let existing = entries(in: context).first(where: { $0.day == day }) {
            existing.weightKg = weightKg
            existing.createdAt = .now
        } else {
            context.insert(WeightEntry(weightKg: weightKg, day: day, calendar: calendar))
        }
        return syncProfile(profile, in: context)
    }

    /// Apaga um registro. Se era o mais recente, o perfil volta para o registro anterior.
    @discardableResult
    static func delete(_ entry: WeightEntry, profile: UserProfile, in context: ModelContext) -> GoalChange? {
        context.delete(entry)
        return syncProfile(profile, in: context)
    }

    /// Perfis criados antes do histórico de peso existir: cria o primeiro registro com o peso do perfil.
    static func ensureInitialEntry(for profile: UserProfile, in context: ModelContext) {
        guard entries(in: context).isEmpty else { return }
        context.insert(WeightEntry(weightKg: profile.weightKg, day: profile.updatedAt))
        try? context.save()
    }

    /// Copia o peso do registro mais recente para o perfil. Sem registros, o perfil fica como está.
    private static func syncProfile(_ profile: UserProfile, in context: ModelContext) -> GoalChange? {
        try? context.save()
        guard let latest = entries(in: context).first, latest.weightKg != profile.weightKg else { return nil }

        let oldWeight = profile.weightKg
        let before = profile.targets
        profile.weightKg = latest.weightKg
        profile.updatedAt = .now
        try? context.save()

        return GoalChange(oldWeightKg: oldWeight, newWeightKg: latest.weightKg, before: before, after: profile.targets)
    }
}
