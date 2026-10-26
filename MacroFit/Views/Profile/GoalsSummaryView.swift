import SwiftUI

/// Resumo das metas: calorias, TMB, TDEE, déficit/superávit, macros, avisos e o lembrete
/// de que são estimativas. Usado no onboarding (ao vivo) e na aba Perfil.
struct GoalsSummaryView: View {
    let targets: NutritionTargets
    let sex: BiologicalSex
    let goal: Goal
    /// Peso atual, para mostrar a perda por semana em % do peso.
    let weightKg: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Meta principal
            VStack(alignment: .leading, spacing: 2) {
                Text("Meta de calorias")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(targets.calories.kcalText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("kcal/dia")
                        .foregroundStyle(.secondary)
                }
            }

            // TMB, TDEE e diferença
            HStack(spacing: 8) {
                StatTile(title: "TMB", value: targets.bmr.kcalText, caption: "em repouso")
                StatTile(title: "Gasto total", value: targets.tdee.kcalText, caption: targets.tdeeIsMeasured ? "pelos registros" : "com atividade")
                StatTile(
                    title: targets.calorieDelta < 0 ? "Déficit" : "Superávit",
                    value: targets.calorieDelta.signedKcalText,
                    caption: "kcal/dia",
                    tint: targets.calorieDelta < 0 ? .blue : .orange
                )
            }

            // Quanto isso muda o peso
            projection

            // Macros em gramas
            HStack(spacing: 8) {
                MacroTile(nutrient: .protein, grams: targets.protein)
                MacroTile(nutrient: .carbs, grams: targets.carbs)
                MacroTile(nutrient: .fat, grams: targets.fat)
            }

            // Avisos
            switch targets.limit {
            case .sexMinimum: WarningLabel(text: minimumWarning)
            case .bmr: WarningLabel(text: "Para não comer menos que a sua TMB (\(targets.bmr.kcalText) kcal, o gasto em repouso), a meta ficou nela. Com isso, o ritmo real fica em ≈ \(abs(targets.weeklyWeightChangeKg).preciseKgText) por semana.")
            case .maxDeficit: WarningLabel(text: "O ritmo escolhido pedia mais de \(NutritionCalculator.maxDailyDeficit.kcalText) kcal de déficit por dia, o máximo do app. Usamos \(NutritionCalculator.maxDailyDeficit.kcalText) kcal (≈ \(abs(targets.weeklyWeightChangeKg).preciseKgText) por semana).")
            case nil: EmptyView()
            }
            if targets.macrosExceedCalories {
                WarningLabel(text: "Proteína e gordura já somam mais que a meta de calorias, então o carboidrato ficou em 0 g. Vale conversar com um nutricionista.")
            }

            Text("Estimativas baseadas em fórmulas populacionais (Mifflin-St Jeor) e em ~7.700 kcal por kg. Nas primeiras semanas a balança costuma cair mais (água). Não substituem o acompanhamento de um nutricionista.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .animation(.default, value: targets)
    }

    /// "≈ −0,73 kg por semana · ≈ −3,1 kg em 30 dias".
    private var projection: some View {
        let weekly = targets.weeklyWeightChangeKg
        let stable = abs(weekly) < 0.05
        let verb = weekly < 0 ? "Perda" : "Ganho"
        return Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(stable ? "Peso estável" : "\(verb) prevista: ≈ \(abs(weekly).preciseKgText) por semana")
                    .font(.subheadline.weight(.semibold))
                if !stable {
                    Text("≈ \(abs(weekly * 30 / 7).preciseKgText) em 30 dias · \(percentText(weekly)) do peso por semana")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: weekly < -0.05 ? "chart.line.downtrend.xyaxis" : stable ? "equal.circle" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("previsao-peso")
    }

    private func percentText(_ weekly: Double) -> String {
        guard weightKg > 0 else { return "" }
        return (abs(weekly) / weightKg * 100).formatted(.number.precision(.fractionLength(0...2))) + "%"
    }

    private var minimumWarning: String {
        let minimum = NutritionCalculator.minimumCalories(for: sex).kcalText
        var text = "A meta calculada ficou abaixo de \(minimum) kcal, o mínimo recomendado. Usamos \(minimum) kcal."
        if targets.calorieDelta > 0 && goal != .gainMuscle {
            text += " Por isso ela fica acima do seu gasto estimado."
        }
        return text
    }
}

/// Pequeno bloco com título, valor e legenda.
private struct StatTile: View {
    let title: String
    let value: String
    let caption: String
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Bloco colorido com a meta em gramas de um macronutriente.
private struct MacroTile: View {
    let nutrient: Nutrient
    let grams: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                NutrientIconView(nutrient: nutrient)
                Text(nutrient.name)
                    .fontWeight(.semibold)
            }
            .font(.caption2)
            .foregroundStyle(nutrient.color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(grams.gramsText)
                .font(.title3.bold().monospacedDigit())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(nutrient.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Aviso em destaque (amarelo).
private struct WarningLabel: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview("Normal") {
    List {
        GoalsSummaryView(
            targets: NutritionCalculator.targets(for: NutritionInput(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate, goal: .recomposition)),
            sex: .male,
            goal: .recomposition,
            weightKg: 80
        )
    }
}

#Preview("Piso aplicado") {
    List {
        GoalsSummaryView(
            targets: NutritionCalculator.targets(for: NutritionInput(sex: .female, age: 70, weightKg: 40, heightCm: 140, activity: .sedentary, goal: .loseFat)),
            sex: .female,
            goal: .loseFat,
            weightKg: 40
        )
    }
}
