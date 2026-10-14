import SwiftUI

/// Linha de refeição: nome, macros resumidos e calorias.
struct MealRow: View {
    let meal: Meal
    /// Mostra o ícone do tipo (útil em listas que misturam tipos, como "repetir refeição").
    var showsType = false

    var body: some View {
        HStack(spacing: 12) {
            if showsType {
                Image(systemName: meal.type.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .lineLimit(1)
                // Refeição montada por alimentos: mostra os gramas de cada um
                if !meal.items.isEmpty {
                    Text(meal.itemsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                MacroLine(macros: meal.macros)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(meal.calories.kcalText)
                    .font(.body.weight(.semibold).monospacedDigit())
                Text("kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// "P 30 g · C 45 g · G 12 g" com as cores de cada macro.
struct MacroLine: View {
    let macros: Macros

    var body: some View {
        HStack(spacing: 10) {
            item("P", macros.protein, .protein)
            item("C", macros.carbs, .carbs)
            item("G", macros.fat, .fat)
        }
        .font(.caption.monospacedDigit())
    }

    private func item(_ letter: String, _ grams: Double, _ nutrient: Nutrient) -> some View {
        HStack(spacing: 3) {
            Text(letter)
                .fontWeight(.bold)
                .foregroundStyle(nutrient.color)
            Text(grams.gramsText)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(nutrient.name) \(grams.gramsText)")
    }
}
