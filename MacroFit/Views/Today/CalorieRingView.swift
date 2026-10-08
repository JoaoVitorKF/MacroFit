import SwiftUI

/// Anel de progresso das calorias: quanto já foi consumido em relação à meta, com o que falta no centro.
struct CalorieRingView: View {
    let consumed: Double
    let goal: Double

    private let lineWidth: CGFloat = 20

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return consumed / goal
    }

    private var remaining: Double { goal - consumed }
    private var isOver: Bool { remaining < 0 }
    private var ringColor: Color { isOver ? .orange : .accentColor }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Trilho
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)

                // Progresso (limitado a uma volta completa)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Centro: o que falta (ou quanto passou)
                VStack(spacing: 2) {
                    Text(abs(remaining).kcalText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(isOver ? .orange : .primary)
                    Text(isOver ? "kcal acima da meta" : "kcal restantes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(lineWidth)
            }
            .frame(width: 190, height: 190)
            .animation(.spring(duration: 0.6), value: progress)

            HStack {
                summary(title: "Consumido", value: consumed)
                Divider().frame(height: 32)
                summary(title: "Meta", value: goal)
                Divider().frame(height: 32)
                VStack(spacing: 2) {
                    Text("Progresso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.headline.monospacedDigit())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calorias")
        .accessibilityValue(
            "\(consumed.kcalText) de \(goal.kcalText) kcal. "
                + (isOver ? "\(abs(remaining).kcalText) acima da meta." : "Faltam \(remaining.kcalText).")
        )
    }

    private func summary(title: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value.kcalText) kcal")
                .font(.headline.monospacedDigit())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 40) {
        CalorieRingView(consumed: 1450, goal: 2345)
        CalorieRingView(consumed: 2600, goal: 2345)
    }
    .padding()
}
