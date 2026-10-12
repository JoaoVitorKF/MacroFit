import SwiftData
import SwiftUI

/// Qual folha de refeição está aberta. Usado pelas abas Hoje e Refeições.
enum MealSheet: Identifiable {
    case new(day: Date, type: MealType? = nil)
    case edit(Meal)

    var id: String {
        switch self {
        case .new(let day, let type): "new-\(day.timeIntervalSince1970)-\(type?.rawValue ?? "")"
        case .edit(let meal): "edit-\(meal.persistentModelID.hashValue)"
        }
    }

    var viewModel: MealFormViewModel {
        switch self {
        case .new(let day, let type): MealFormViewModel(day: day, type: type)
        case .edit(let meal): MealFormViewModel(editing: meal)
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

                Section("Refeição") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Nome (ex.: frango com arroz)", text: $viewModel.name)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("campo-nome")
                            .submitLabel(.done)
                        // Só mostra o erro de nome vazio depois que algo foi digitado e apagado
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
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle(viewModel.isEditing ? "Editar refeição" : "Nova refeição")
            .navigationBarTitleDisplayMode(.inline)
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
}

#Preview {
    MealFormView(sheet: .new(day: .now))
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
