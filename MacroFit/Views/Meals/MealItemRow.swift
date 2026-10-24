import SwiftUI

/// Um alimento na refeição: nome, gramas (com −10/+10) e quanto isso dá em calorias e macros.
/// Alimentos contados mostram as unidades ("≈ 2 ovos"); o cadeado indica gramas que a sugestão não muda.
struct MealItemRow: View {
    @Binding var draft: MealFormViewModel.ItemDraft
    let onAdjust: (Double) -> Void
    let onToggleLock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(draft.item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                if let grams = draft.grams, let units = draft.item.unit?.describe(grams: grams) {
                    Text("≈ \(units)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("unidades-\(draft.item.name)")
                }
                if draft.isLocked {
                    // Estilo explícito: vários botões na mesma linha de Form
                    Button(action: onToggleLock) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Destravar gramas de \(draft.item.shortName)")
                    .accessibilityIdentifier("cadeado-\(draft.item.name)")
                }
            }

            HStack(spacing: 8) {
                Button { onAdjust(-10) } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Menos 10 gramas de \(draft.item.shortName)")

                TextField("100", text: $draft.gramsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.body.monospacedDigit())
                    .frame(width: 70)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("gramas-\(draft.item.name)")
                Text("g")
                    .foregroundStyle(.secondary)

                Button { onAdjust(10) } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Mais 10 gramas de \(draft.item.shortName)")

                Spacer(minLength: 4)

                if let macros = draft.macros {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(macros.calories.kcalText) kcal")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("P \(macros.protein.gramsText) · C \(macros.carbs.gramsText) · G \(macros.fat.gramsText)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("valores-\(draft.item.name)")
                } else {
                    Text("1 a 2000 g")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .animation(.default, value: draft.gramsText)
        }
        .padding(.vertical, 4)
    }
}
