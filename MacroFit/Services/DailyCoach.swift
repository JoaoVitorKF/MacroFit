import Foundation
import SwiftData

/// Conquista do dia, comemorada quando acontece (não ao abrir o app com a meta já batida).
enum Achievement: Equatable {
    /// A proteína do dia acabou de alcançar a meta.
    case proteinGoal
    /// As calorias do dia acabaram de entrar na faixa da meta (95–105%).
    case caloriesInRange

    var title: String {
        switch self {
        case .proteinGoal: "Meta de proteína batida!"
        case .caloriesInRange: "Calorias na meta!"
        }
    }

    var symbol: String {
        switch self {
        case .proteinGoal: "bolt.heart.fill"
        case .caloriesInRange: "flame.fill"
        }
    }
}

/// Dica mostrada na tela Hoje, conforme o progresso do dia.
struct DailyTip: Equatable {
    enum Tone: Equatable {
        case info
        case success
        case warning
    }

    let symbol: String
    let title: String
    let message: String
    let tone: Tone
    /// Refeição do histórico sugerida (o card mostra o botão "Adicionar").
    var suggestion: Meal?

    static func == (lhs: DailyTip, rhs: DailyTip) -> Bool {
        lhs.symbol == rhs.symbol && lhs.title == rhs.title && lhs.message == rhs.message
            && lhs.tone == rhs.tone && lhs.suggestion?.persistentModelID == rhs.suggestion?.persistentModelID
    }
}

/// Regras de comemoração e de dicas. Funções puras: recebem os números e devolvem o que mostrar.
enum DailyCoach {

    /// Faixa das calorias considerada "na meta".
    static let calorieRange = 0.95...1.05

    // MARK: - Comemoração

    /// O que foi conquistado ao passar de `before` para `after` (ex.: ao salvar uma refeição).
    static func achievements(before: Macros, after: Macros, targets: NutritionTargets) -> [Achievement] {
        var result: [Achievement] = []

        if targets.protein > 0, before.protein < targets.protein, after.protein >= targets.protein {
            result.append(.proteinGoal)
        }

        if targets.calories > 0 {
            let beforeRatio = before.calories / targets.calories
            let afterRatio = after.calories / targets.calories
            if beforeRatio < calorieRange.lowerBound, calorieRange.contains(afterRatio) {
                result.append(.caloriesInRange)
            }
        }
        return result
    }

    /// Mensagem da comemoração (uma ou duas conquistas de uma vez).
    static func celebrationMessage(for achievements: [Achievement], consumed: Macros, targets: NutritionTargets) -> String {
        switch (achievements.contains(.proteinGoal), achievements.contains(.caloriesInRange)) {
        case (true, true):
            "Proteína e calorias na meta. Dia perfeito para a recomposição!"
        case (true, false):
            "\(consumed.protein.gramsText) de proteína hoje. É isso que constrói músculo."
        case (false, true):
            "\(consumed.calories.kcalText) de \(targets.calories.kcalText) kcal. Na medida certa."
        case (false, false):
            ""
        }
    }

    // MARK: - Dicas

    /// Dica do momento para o dia de hoje.
    /// - Parameters:
    ///   - history: refeições anteriores (para sugerir algo que caiba no que falta).
    ///   - hour: hora atual (0–23), para adaptar a dica ao período do dia.
    static func tip(
        consumed: Macros,
        targets: NutritionTargets,
        mealCount: Int,
        hour: Int,
        history: [Meal] = []
    ) -> DailyTip {
        let remainingKcal = targets.calories - consumed.calories
        let remainingProtein = targets.protein - consumed.protein
        let calorieRatio = targets.calories > 0 ? consumed.calories / targets.calories : 0
        let proteinDone = remainingProtein <= 0

        // Nada registrado ainda
        if mealCount == 0 {
            if hour < 11 {
                return DailyTip(
                    symbol: "sunrise.fill",
                    title: "Bom dia!",
                    message: "Comece registrando o café da manhã. Incluir proteína logo cedo ajuda a chegar aos \(targets.protein.gramsText) do dia.",
                    tone: .info
                )
            }
            return DailyTip(
                symbol: "square.and.pencil",
                title: "Nada registrado hoje",
                message: "Toque em Adicionar refeição ou use um atalho do Adicionar rápido para começar.",
                tone: .info
            )
        }

        // Passou da meta de calorias
        if calorieRatio > calorieRange.upperBound {
            return DailyTip(
                symbol: "exclamationmark.triangle.fill",
                title: "\(abs(remainingKcal).kcalText) kcal acima da meta",
                message: proteinDone
                    ? "Tudo bem: a proteína está garantida. Amanhã é só seguir o plano."
                    : "Tudo bem. Se ainda for comer, prefira proteína magra e legumes. Amanhã é só seguir o plano.",
                tone: .warning
            )
        }

        // Proteína e calorias na meta
        if proteinDone && calorieRange.contains(calorieRatio) {
            return DailyTip(
                symbol: "checkmark.seal.fill",
                title: "Dia redondo",
                message: "Proteína e calorias na meta. Agora é descansar bem para o músculo se recuperar.",
                tone: .success
            )
        }

        // Proteína batida, faltam calorias
        if proteinDone {
            return DailyTip(
                symbol: "bolt.heart.fill",
                title: "Proteína batida!",
                message: "Faltam \(remainingKcal.kcalText) kcal. Complete com carboidratos e gorduras boas: arroz, batata, frutas, azeite, castanhas.",
                tone: .success
            )
        }

        // Falta bastante proteína: sugere algo do histórico que caiba
        if remainingProtein >= 15 {
            let lateHint = hour >= 18 ? " Ainda dá tempo no jantar." : ""
            if let meal = suggestion(remainingProtein: remainingProtein, remainingKcal: remainingKcal, history: history) {
                var tip = DailyTip(
                    symbol: "lightbulb.fill",
                    title: "Faltam \(remainingProtein.gramsText) de proteína",
                    message: "Que tal \(meal.name)? São \(meal.protein.gramsText) de proteína e \(meal.calories.kcalText) kcal.\(lateHint)",
                    tone: .info
                )
                tip.suggestion = meal
                return tip
            }
            return DailyTip(
                symbol: "lightbulb.fill",
                title: "Faltam \(remainingProtein.gramsText) de proteína",
                message: "Boas fontes: peito de frango (≈31 g em 100 g), atum em lata (≈25 g), iogurte com whey (≈25 g), ovos (≈6 g cada).\(lateHint)",
                tone: .info
            )
        }

        // Fim do dia com muitas calorias faltando: comer pouco demais atrapalha o ganho de massa
        if hour >= 20 && calorieRatio < 0.6 {
            return DailyTip(
                symbol: "moon.stars.fill",
                title: "Faltam \(remainingKcal.kcalText) kcal",
                message: "Comer muito abaixo da meta atrapalha o ganho de massa. Um lanche antes de dormir ajuda.",
                tone: .info
            )
        }

        // Padrão: resumo do que falta
        return DailyTip(
            symbol: "chart.pie.fill",
            title: "Quase lá",
            message: "Faltam \(max(remainingKcal, 0).kcalText) kcal e \(max(remainingProtein, 0).gramsText) de proteína. Você está em \(min(calorieRatio, 1).formatted(.percent.precision(.fractionLength(0)))) do dia.",
            tone: .info
        )
    }

    /// Refeição do histórico com mais proteína por caloria que caiba no que falta
    /// (proteína até 10 g além do que falta, calorias dentro do que falta).
    static func suggestion(remainingProtein: Double, remainingKcal: Double, history: [Meal]) -> Meal? {
        MealHistory.uniqueRecent(history)
            .filter { meal in
                meal.protein >= 10
                    && meal.calories > 0
                    && meal.protein <= remainingProtein + 10
                    && meal.calories <= remainingKcal
            }
            .max { lhs, rhs in
                (lhs.protein / lhs.calories) < (rhs.protein / rhs.calories)
            }
    }
}
