import SwiftUI

/// Barra de progresso de um macronutriente em gramas: consumido / meta e quanto falta.
struct MacroBarView: View {
    let nutrient: Nutrient
    let consumed: Double
    let goal: Double

    private var progress: Double {
        guard goal > 0 else { return consumed > 0 ? 1 : 0 }
        return min(consumed / goal, 1)
    }

    private var remaining: Double { goal - consumed }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(nutrient.name, systemImage: nutrient.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(nutrient.color)
                Spacer()
                Text("\(consumed.kcalText) / \(goal.gramsText)")
                    .font(.subheadline.monospacedDigit())
                    .contentTransition(.numericText())
            }

            // Barra
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(nutrient.color.opacity(0.15))
                    Capsule()
                        .fill(nutrient.color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 10)
            .animation(.spring(duration: 0.5), value: progress)

            Text(remainingText)
                .font(.caption)
                .foregroundStyle(isOverAndShouldWarn ? .orange : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nutrient.name)
        .accessibilityValue("\(consumed.gramsText) de \(goal.gramsText). \(remainingText)")
    }

    /// Passar da meta de proteína não é problema na recomposição; dos outros macros, avisa em laranja.
    private var isOverAndShouldWarn: Bool {
        remaining < 0 && nutrient != .protein
    }

    private var remainingText: String {
        if remaining < 0 && nutrient == .protein {
            return "Meta atingida (+\(abs(remaining).gramsText))"
        }
        if remaining < 0 {
            return "\(abs(remaining).gramsText) acima da meta"
        }
        if remaining.rounded() == 0 {
            return "Meta atingida"
        }
        return "Faltam \(remaining.gramsText)"
    }
}

#Preview {
    VStack(spacing: 20) {
        MacroBarView(nutrient: .protein, consumed: 95, goal: 160)
        MacroBarView(nutrient: .carbs, consumed: 264, goal: 264)
        MacroBarView(nutrient: .fat, consumed: 85, goal: 72)
    }
    .padding()
}
