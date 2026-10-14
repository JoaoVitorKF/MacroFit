import SwiftData
import SwiftUI

/// Qual folha de refeição está aberta. Usado pelas abas Hoje e Refeições.
enum MealSheet: Identifiable {
    case new(day: Date, type: MealType? = nil)
    case edit(Meal)
    /// Nova refeição já preenchida com outra (atalho "editar antes de adicionar").
    case fromTemplate(Meal, day: Date, portion: Portion)

    var id: String {
        switch self {
        case .new(let day, let type): "new-\(day.timeIntervalSince1970)-\(type?.rawValue ?? "")"
        case .edit(let meal): "edit-\(meal.persistentModelID.hashValue)"
        case .fromTemplate(let meal, let day, let portion):
            "template-\(meal.persistentModelID.hashValue)-\(day.timeIntervalSince1970)-\(portion.rawValue)"
        }
    }

    var viewModel: MealFormViewModel {
        switch self {
        case .new(let day, let type): MealFormViewModel(day: day, type: type)
        case .edit(let meal): MealFormViewModel(editing: meal)
        case .fromTemplate(let meal, let day, let portion): MealFormViewModel(day: day, template: meal, portion: portion)
        }
    }
}

/// Formulário para criar, editar ou repetir uma refeição.
struct MealFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MealFormViewModel

    init(sheet: MealSheet) {
        _viewModel = State(initialValue: sheet.viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.isEditing {
                    Section {
                        NavigationLink {
                            RepeatMealPicker { meal in
                                viewModel.fill(from: meal)
                            }
                        } label: {
                            Label("Repetir refeição anterior", systemImage: "arrow.clockwise")
                        }
                    }
                }

                Section {
                    Picker("Como registrar", selection: $viewModel.mode) {
                        Text("Por alimentos").tag(MealFormViewModel.EntryMode.foods)
                        Text("Digitar valores").tag(MealFormViewModel.EntryMode.manual)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("modo-entrada")
                } footer: {
                    Text(viewModel.mode == .foods
                         ? "Escolha os alimentos e os gramas: calorias e macros são calculados pela tabela TACO."
                         : "Para produtos com rótulo: digite calorias e macros da porção que você comeu.")
                }

                Section("Refeição") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(namePlaceholder, text: $viewModel.name)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("campo-nome")
                            .submitLabel(.done)
                        // Só mostra o erro de nome depois que algo foi digitado
                        if !viewModel.name.isEmpty, let error = viewModel.nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Picker("Tipo", selection: $viewModel.type) {
                        ForEach(MealType.allCases) { type in
                            Label(type.displayName, systemImage: type.symbol).tag(type)
                        }
                    }
                }

                // Porção: aparece ao repetir ou editar uma refeição
                if viewModel.showsPortion {
                    Section {
                        Picker("Porção", selection: Binding(get: { viewModel.portion }, set: { viewModel.apply($0) })) {
                            ForEach(Portion.allCases) { portion in
                                Text(portion.shortLabel).tag(portion)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("seletor-porcao")
                    } header: {
                        Text("Porção")
                    } footer: {
                        Text(viewModel.mode == .foods
                             ? "Multiplica os gramas de todos os alimentos."
                             : "Multiplica calorias e macros da refeição original.")
                    }
                }

                switch viewModel.mode {
                case .foods:
                    foodsSections
                case .manual:
                    manualSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle(viewModel.isEditing ? "Editar refeição" : "Nova refeição")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: viewModel.mode)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if viewModel.save(in: context) {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }

    private var namePlaceholder: String {
        if viewModel.mode == .foods {
            return viewModel.autoName.isEmpty ? "Nome (opcional)" : viewModel.autoName
        }
        return "Nome (ex.: frango com arroz)"
    }

    // MARK: - Por alimentos

    @ViewBuilder
    private var foodsSections: some View {
        Section {
            MealTextEntry(viewModel: viewModel)

            ForEach($viewModel.items) { $draft in
                MealItemRow(draft: $draft) { delta in
                    viewModel.adjustGrams(of: draft.id, by: delta)
                }
            }
            .onDelete { viewModel.removeItems(at: $0) }

            NavigationLink {
                FoodPickerView { food in
                    viewModel.add(food)
                }
            } label: {
                Label("Adicionar alimento", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .accessibilityIdentifier("adicionar-alimento")
        } header: {
            Text("Alimentos")
        } footer: {
            if !viewModel.items.isEmpty, let error = viewModel.itemsError {
                Text(error).foregroundStyle(.red)
            } else if !viewModel.items.isEmpty {
                Text("Deslize um alimento para a esquerda para remover.")
            }
        }

        MealBudgetSection(viewModel: viewModel)

        if let total = viewModel.itemsTotal {
            Section("Total da refeição") {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(total.calories.kcalText) kcal")
                        .font(.title2.bold().monospacedDigit())
                        .contentTransition(.numericText())
                    Spacer()
                    MacroLine(macros: total)
                }
                .animation(.default, value: total)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("total-refeicao")
            }
        }
    }

    // MARK: - Digitar valores

    private var manualSection: some View {
        Section {
            NumberField(field: .calories, text: $viewModel.caloriesText)
            NumberField(field: .protein, text: $viewModel.proteinText)
            NumberField(field: .carbs, text: $viewModel.carbsText)
            NumberField(field: .fat, text: $viewModel.fatText)

            if let estimated = viewModel.caloriesFromMacros,
               viewModel.caloriesText.isEmpty || viewModel.caloriesLookInconsistent {
                Button {
                    viewModel.useCaloriesFromMacros()
                } label: {
                    Label("Usar \(estimated.kcalText) kcal calculadas pelos macros", systemImage: "function")
                        .font(.subheadline)
                }
            }
        } header: {
            Text("Valores")
        } footer: {
            if viewModel.caloriesLookInconsistent, let estimated = viewModel.caloriesFromMacros {
                Text("As calorias digitadas não batem com os macros (≈ \(estimated.kcalText) kcal). Confira o rótulo.")
            } else {
                Text("Use 0 quando o alimento não tiver aquele macro.")
            }
        }
    }
}

/// Campo para escrever (ou ditar pelo microfone do teclado) a refeição: "200g de arroz e 150g de carne".
private struct MealTextEntry: View {
    @Bindable var viewModel: MealFormViewModel
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @State private var text = ""
    @State private var result: (message: String, isProblem: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(Color.accentColor)
                TextField("Ex.: 200g de arroz e 150g de carne", text: $text)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .accessibilityIdentifier("campo-texto-refeicao")
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Adicionar alimentos do texto")
                .accessibilityIdentifier("interpretar-texto")
            }
            Text(result?.message ?? "Escreva ou toque no microfone do teclado e fale a refeição.")
                .font(.caption)
                .foregroundStyle(result?.isProblem == true ? Color.orange : Color.secondary)
                .accessibilityIdentifier("resultado-texto")
        }
        .padding(.vertical, 2)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let outcome = withAnimation {
            viewModel.addFromText(trimmed, custom: customFoods.map(\.food))
        }
        var parts: [String] = []
        if outcome.added > 0 {
            parts.append(outcome.added == 1 ? "1 alimento adicionado." : "\(outcome.added) alimentos adicionados.")
        }
        if !outcome.notFound.isEmpty {
            let names = outcome.notFound.map { "\"\($0)\"" }.joined(separator: ", ")
            parts.append("Não encontrei \(names): use Adicionar alimento ou cadastre pelo rótulo.")
        }
        if parts.isEmpty { parts.append("Não entendi. Tente algo como \"150g de frango\".") }
        result = (parts.joined(separator: " "), !outcome.notFound.isEmpty || outcome.added == 0)
        if outcome.notFound.isEmpty && outcome.added > 0 { text = "" }
    }
}

/// Um alimento na refeição: nome, gramas (com −10/+10) e quanto isso dá em calorias e proteína.
private struct MealItemRow: View {
    @Binding var draft: MealFormViewModel.ItemDraft
    let onAdjust: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.item.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            HStack(spacing: 8) {
                // Estilo explícito: vários botões na mesma linha de Form
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

#Preview {
    MealFormView(sheet: .new(day: .now))
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
