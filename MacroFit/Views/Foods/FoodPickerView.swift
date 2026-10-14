import SwiftData
import SwiftUI

/// Busca de alimentos (TACO + alimentos próprios). Tocar num alimento o escolhe e volta.
struct FoodPickerView: View {
    let onPick: (Food) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @State private var query = ""
    @State private var isCreating = false

    private var custom: [Food] { customFoods.map(\.food) }
    private var results: [Food] { FoodDatabase.shared.search(query, custom: custom) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        List {
            if isSearching {
                Section {
                    ForEach(results) { food in
                        row(food)
                    }
                } footer: {
                    if results.isEmpty {
                        Text("Nenhum alimento encontrado. Cadastre-o abaixo com os valores do rótulo.")
                    }
                }
            } else {
                if !custom.isEmpty {
                    Section("Meus alimentos") {
                        ForEach(customFoods) { customFood in
                            row(customFood.food)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        context.delete(customFood)
                                        try? context.save()
                                    } label: {
                                        Label("Apagar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                Section("Mais comuns") {
                    ForEach(FoodDatabase.shared.common()) { food in
                        row(food)
                    }
                }
            }

            Section {
                Button {
                    isCreating = true
                } label: {
                    Label("Cadastrar alimento pelo rótulo", systemImage: "plus.rectangle.on.rectangle")
                }
            } footer: {
                Text("Valores da TACO (Tabela Brasileira de Composição de Alimentos, NEPA/UNICAMP), por 100 g. Para produtos de marca (whey, pão de forma…), cadastre pelo rótulo.")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar: arroz, frango, feijão…")
        .navigationTitle("Adicionar alimento")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isCreating) {
            CustomFoodFormView(initialName: query) { food in
                onPick(food)
                dismiss()
            }
        }
    }

    private func row(_ food: Food) -> some View {
        Button {
            onPick(food)
            dismiss()
        } label: {
            FoodRow(food: food)
        }
        .foregroundStyle(.primary)
        .accessibilityIdentifier("alimento-\(food.name)")
    }
}

/// Linha de alimento: nome e valores por 100 g.
struct FoodRow: View {
    let food: Food

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(food.name)
                    .lineLimit(2)
                if food.isCustom {
                    Image(systemName: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Meu alimento")
                }
            }
            Text("100 g: \(food.per100g.calories.kcalText) kcal · P \(food.per100g.protein.gramsText) · C \(food.per100g.carbs.gramsText) · G \(food.per100g.fat.gramsText)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Cadastro de alimento próprio a partir do rótulo (valores de uma porção de X gramas).
struct CustomFoodFormView: View {
    let onSaved: (Food) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var portionText = "100"
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

    init(initialName: String = "", onSaved: @escaping (Food) -> Void) {
        self.onSaved = onSaved
        _name = State(initialValue: initialName.prefix(1).uppercased() + initialName.dropFirst())
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Valores do rótulo convertidos para 100 g, ou `nil` se algo estiver inválido.
    private var per100g: Macros? {
        guard !trimmedName.isEmpty, trimmedName.count <= MealFormViewModel.maxNameLength,
              let portion = NumericField.grams.value(from: portionText),
              let calories = NumericField.calories.value(from: caloriesText),
              let protein = NumericField.protein.value(from: proteinText),
              let carbs = NumericField.carbs.value(from: carbsText),
              let fat = NumericField.fat.value(from: fatText) else { return nil }
        return CustomFood.per100g(fromPortion: Macros(calories: calories, protein: protein, carbs: carbs, fat: fat), grams: portion)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alimento") {
                    TextField("Nome (ex.: Whey protein baunilha)", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("campo-nome-alimento")
                }

                Section {
                    NumberField(field: .grams, text: $portionText, placeholder: "100")
                    NumberField(field: .calories, text: $caloriesText)
                    NumberField(field: .protein, text: $proteinText)
                    NumberField(field: .carbs, text: $carbsText)
                    NumberField(field: .fat, text: $fatText)
                } header: {
                    Text("Valores do rótulo")
                } footer: {
                    Text("Copie da tabela nutricional da embalagem. Se o rótulo for \"porção de 30 g\", coloque 30 em Quantidade e os valores dessa porção.")
                }

                if let per100g {
                    Section("Equivale a 100 g") {
                        Text("\(per100g.calories.kcalText) kcal · P \(per100g.protein.gramsText) · C \(per100g.carbs.gramsText) · G \(per100g.fat.gramsText)")
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
            .keyboardDoneButton()
            .navigationTitle("Novo alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        guard let per100g else { return }
                        let customFood = CustomFood(name: trimmedName, per100g: per100g)
                        context.insert(customFood)
                        try? context.save()
                        onSaved(customFood.food)
                        dismiss()
                    }
                    .disabled(per100g == nil)
                }
            }
        }
    }
}
