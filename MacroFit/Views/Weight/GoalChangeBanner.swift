import SwiftUI

/// Aviso mostrado depois de um novo peso mudar as metas: o que era e o que ficou.
struct GoalChangeBanner: View {
    let change: GoalChange
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Metas atualizadas", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Fechar aviso")
            }

            Text("Novo peso: \(change.newWeightKg.kgText) (\((change.newWeightKg - change.oldWeightKg).signedKgText))")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 4) {
                row("Calorias", change.before.calories.kcalText, change.after.calories.kcalText, unit: "kcal")
                row("Proteína", change.before.protein.kcalText, change.after.protein.kcalText, unit: "g")
                row("Carboidrato", change.before.carbs.kcalText, change.after.carbs.kcalText, unit: "g")
                row("Gordura", change.before.fat.kcalText, change.after.fat.kcalText, unit: "g")
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    private func row(_ title: String, _ before: String, _ after: String, unit: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            if before == after {
                Text("\(after) \(unit)")
            } else {
                HStack(spacing: 0) {
                    Text("\(before) → ")
                        .foregroundStyle(.secondary)
                    Text("\(after) \(unit)")
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
