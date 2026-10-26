import Foundation
import SwiftData

/// Gasto real estimado pelos registros (balanço de energia), em vez de só pela fórmula.
///
/// Se nos últimos 28 dias a pessoa comeu em média X kcal por dia e o peso caiu Y kg por dia,
/// o gasto foi X + Y × 7.700. A tendência do peso é a reta dos mínimos quadrados das pesagens
/// (uma pesagem isolada mente: água, sal e intestino mexem ±1 kg de um dia para o outro).
///
/// Cuidados para não reagir a ruído:
/// - só calcula com dados suficientes (`minimumLoggedDays` dias com refeições e `minimumWeighIns`
///   pesagens cobrindo `minimumSpanDays` dias);
/// - dias com menos de `minimumDayKcal` registrados contam como esquecidos e ficam de fora;
/// - o valor medido fica entre 75% e 125% da fórmula;
/// - o resultado mistura medido e fórmula na proporção dos dados (28 dias completos = 100% medido).
/// Funções puras, testáveis.
enum EnergyBalance {

    static let windowDays = 28
    static let minimumLoggedDays = 14
    static let minimumWeighIns = 3
    static let minimumSpanDays = 14
    static let minimumDayKcal = 800.0
    /// O medido fica entre 75% e 125% da fórmula.
    static let maxDeviation = 0.25

    struct Estimate: Equatable {
        /// Gasto usado nas metas: mistura do medido com a fórmula.
        let tdee: Double
        /// Gasto pelo balanço (já limitado a ±25% da fórmula).
        let measuredTdee: Double
        /// `true` se o medido passou dos ±25% e foi limitado.
        let wasClamped: Bool
        /// Peso do medido na mistura (0,5 a 1).
        let confidence: Double
        let averageIntake: Double
        /// Tendência do peso em kg por semana (negativo = perdendo).
        let weeklyTrendKg: Double
        let loggedDays: Int
        let weighIns: Int
    }

    enum Result: Equatable {
        case ready(Estimate)
        /// Faltam dados: quanto já existe de cada requisito.
        case needsMoreData(loggedDays: Int, weighIns: Int, spanDays: Int)

        var estimate: Estimate? {
            if case .ready(let estimate) = self { return estimate }
            return nil
        }
    }

    /// Primeiro dia da janela (28 dias antes de hoje). Hoje fica de fora: o dia ainda não acabou.
    static func windowStart(today: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -windowDays, to: start) ?? start
    }

    /// - Parameters:
    ///   - meals: (dia, kcal) de cada refeição; somadas por dia aqui.
    ///   - weights: (dia, kg) de cada pesagem.
    ///   - formulaTdee: gasto pela fórmula (Mifflin × atividade), referência e âncora da mistura.
    static func estimate(
        meals: [(day: Date, calories: Double)],
        weights: [(day: Date, kg: Double)],
        formulaTdee: Double,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Result {
        let todayStart = calendar.startOfDay(for: today)
        let start = windowStart(today: today, calendar: calendar)

        // Calorias por dia, só dias inteiros da janela e com registro razoável
        var perDay: [Date: Double] = [:]
        for meal in meals {
            let day = calendar.startOfDay(for: meal.day)
            guard day >= start && day < todayStart else { continue }
            perDay[day, default: 0] += meal.calories
        }
        let loggedIntakes = perDay.values.filter { $0 >= minimumDayKcal }

        // Pesagens da janela (hoje pode: a pesagem da manhã já vale)
        let points = weights
            .map { (day: calendar.startOfDay(for: $0.day), kg: $0.kg) }
            .filter { $0.day >= start && $0.day <= todayStart }
            .sorted { $0.day < $1.day }
        let spanDays = points.count >= 2 ? days(from: points.first!.day, to: points.last!.day, calendar: calendar) : 0

        guard loggedIntakes.count >= minimumLoggedDays, points.count >= minimumWeighIns, spanDays >= minimumSpanDays,
              let slope = trendSlope(points.map { (Double(days(from: start, to: $0.day, calendar: calendar)), $0.kg) })
        else {
            return .needsMoreData(loggedDays: loggedIntakes.count, weighIns: points.count, spanDays: spanDays)
        }

        let averageIntake = loggedIntakes.reduce(0, +) / Double(loggedIntakes.count)
        let raw = averageIntake - slope * NutritionCalculator.kcalPerKgBodyWeight
        let low = formulaTdee * (1 - maxDeviation), high = formulaTdee * (1 + maxDeviation)
        let measured = min(max(raw, low), high)
        let confidence = min(Double(min(loggedIntakes.count, spanDays)) / Double(windowDays), 1)

        return .ready(Estimate(
            tdee: formulaTdee + confidence * (measured - formulaTdee),
            measuredTdee: measured,
            wasClamped: measured != raw,
            confidence: confidence,
            averageIntake: averageIntake,
            weeklyTrendKg: slope * 7,
            loggedDays: loggedIntakes.count,
            weighIns: points.count
        ))
    }

    /// Inclinação (kg por dia) da reta dos mínimos quadrados. `nil` com menos de 2 pontos ou todos no mesmo dia.
    static func trendSlope(_ points: [(x: Double, y: Double)]) -> Double? {
        guard points.count >= 2 else { return nil }
        let n = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / n
        let meanY = points.map(\.y).reduce(0, +) / n
        let sxx = points.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
        guard sxx > 0 else { return nil }
        let sxy = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) }
        return sxy / sxx
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

// MARK: - Ligação com o SwiftData

/// Busca refeições e pesagens da janela, calcula o `EnergyBalance` e guarda o gasto no perfil.
@MainActor
enum EnergyStore {
    /// Recalcula e atualiza `profile.measuredTdee` (só grava se mudou). Chamado ao abrir o app,
    /// ao voltar para ele e ao abrir o Perfil.
    @discardableResult
    static func refresh(_ profile: UserProfile, in context: ModelContext, today: Date = .now) -> EnergyBalance.Result {
        let start = EnergyBalance.windowStart(today: today)
        let meals = (try? context.fetch(FetchDescriptor<Meal>(predicate: #Predicate { $0.day >= start }))) ?? []
        let weights = (try? context.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.day >= start }))) ?? []
        let formulaTdee = NutritionCalculator.targets(for: profile.formulaInput).tdee

        let result = EnergyBalance.estimate(
            meals: meals.map { ($0.day, $0.calories) },
            weights: weights.map { ($0.day, $0.weightKg) },
            formulaTdee: formulaTdee,
            today: today
        )
        let newValue = result.estimate.map { ($0.tdee).rounded() }
        if profile.measuredTdee != newValue {
            profile.measuredTdee = newValue
            try? context.save()
        }
        return result
    }
}
