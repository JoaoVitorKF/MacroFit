import SwiftData
import SwiftUI

/// "O que vou comer?": o usuário diz (ou dita) os alimentos e a tela já mostra quantos gramas de cada um
/// cabem no que sobra para a refeição. Quantidades ditas ("2 ovos") ficam travadas; mexer no − / + de um
/// alimento o trava e reequilibra os outros. "Registrar" salva a refeição como está.
struct WhatToEatView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomFood.name) private var customFoods: [CustomFood]
    @State private var viewModel: MealFormViewModel
    @State private var text = ""
    @State private var notFound: [String] = []
    @State private var didStart = false
    private let initialText: String

    init(text: String, day: Date) {
        initialText = text
        _viewModel = State(initialValue: MealFormViewModel(day: day))
    }

    var body: some View {
        NavigationStack {
            MealBudgetReader(day: viewModel.day, type: viewModel.type) { budget in
                content(budget: budget)
            }
            .navigationTitle("O que vou comer?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func content(budget: Macros?) -> some View {
        Form {
            Section {
                Picker("Refeição", selection: $viewModel.type) {
                    ForEach(MealType.allCases) { type in
                        Text(type.shortName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("tipo-plano")

                if let budget {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(budget.calories < 50
                             ? "A meta de calorias de hoje já foi atingida."
                             : "Para \(viewModel.type.withArticle) sobram ~\(budget.calories.kcalText) kcal")
                            .font(.subheadline.weight(.semibold))
                        MacroLine(macros: budget)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("orcamento-plano")
                }
            }

            if !viewModel.items.isEmpty {
                Section {
                    ForEach($viewModel.items) { $draft in
                        MealItemRow(draft: $draft) { delta in
                            withAnimation(.spring(duration: 0.35)) {
                                if let budget {
                                    viewModel.adjustAndRebalance(draft.id, by: delta, budget: budget)
                                } else {
                                    viewModel.adjustGrams(of: draft.id, by: delta)
                                }
                            }
                        } onToggleLock: {
                            withAnimation(.spring(duration: 0.35)) {
                                viewModel.toggleLock(draft.id)
                                if let budget { viewModel.suggestPortions(budget: budget) }
                            }
                        }
                    }
                    .onDelete { offsets in
                        withAnimation {
                            viewModel.removeItems(at: offsets)
                            if let budget { viewModel.suggestPortions(budget: budget) }
                        }
                    }
                } header: {
                    Text("Pode comer")
                } footer: {
                    Text("Mexeu no − / + de um alimento? Ele fica com cadeado e os outros se ajustam para caber. Toque no cadeado para soltar. Deslize para a esquerda para remover.")
                }
            }

            if !notFound.isEmpty {
                Section {
                    ForEach(notFound, id: \.self) { query in
                        NavigationLink {
                            FoodPickerView { food in
                                withAnimation {
                                    viewModel.add(food)
                                    notFound.removeAll { $0 == query }
                                    if let budget { viewModel.suggestPortions(budget: budget) }
                                }
                            }
                        } label: {
                            Label("\"\(query)\": escolher na lista", systemImage: "magnifyingglass")
                        }
                    }
                } header: {
                    Text("Não encontrei")
                } footer: {
                    Text("Escolha o alimento mais parecido ou cadastre pelo rótulo.")
                }
            }

            Section {
                textEntry(budget: budget)
            } footer: {
                Text("Diga só o alimento e eu calculo os gramas. Com quantidade (\"2 ovos\", \"150g de arroz\"), ela fica como você disse.")
            }

            if let total = viewModel.itemsTotal {
                Section("Total") {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(total.calories.kcalText) kcal")
                            .font(.title2.bold().monospacedDigit())
                            .contentTransition(.numericText())
                        Spacer()
                        MacroLine(macros: total)
                    }
                    .animation(.default, value: total)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("total-plano")

                    if let budget, budget.calories > 0 {
                        MealUsageView(total: total, budget: budget)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .safeAreaInset(edge: .bottom) {
            registerButton
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            add(initialText, budget: budget)
        }
        // Trocar o tipo de refeição muda o que sobra: recalcula os gramas
        .onChange(of: budget) { _, newBudget in
            guard let newBudget else { return }
            withAnimation(.spring(duration: 0.35)) {
                viewModel.suggestPortions(budget: newBudget)
            }
        }
    }

    /// Campo para acrescentar mais alimentos ("e uma salada").
    private func textEntry(budget: Macros?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .foregroundStyle(Color.accentColor)
            TextField("Mais alguma coisa? Ex.: salada", text: $text)
                .submitLabel(.done)
                .onSubmit { submit(budget: budget) }
                .accessibilityIdentifier("campo-mais-alimentos")
            Button { submit(budget: budget) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Adicionar alimentos do texto")
        }
    }

    private var registerButton: some View {
        Button {
            if viewModel.save(in: context) {
                dismiss()
            }
        } label: {
            Label("Registrar \(viewModel.type.withIn)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .foregroundStyle(.accentForeground)
        .disabled(!viewModel.isValid)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityIdentifier("registrar-plano")
    }

    private func submit(budget: Macros?) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        add(trimmed, budget: budget)
        text = ""
    }

    /// Interpreta o texto e recalcula juntos todos os alimentos não travados (a refeição inteira tem que caber).
    private func add(_ text: String, budget: Macros?) {
        withAnimation {
            let outcome = viewModel.addFromText(text, custom: customFoods.map(\.food))
            if let budget { viewModel.suggestPortions(budget: budget) }
            notFound.append(contentsOf: outcome.notFound.filter { !notFound.contains($0) })
        }
    }
}

#Preview {
    WhatToEatView(text: "arroz, feijão e frango", day: .now)
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
