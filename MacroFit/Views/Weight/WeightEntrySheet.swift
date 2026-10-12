import SwiftData
import SwiftUI

/// Folha para registrar o peso de um dia (hoje por padrão; não aceita datas futuras).
struct WeightEntrySheet: View {
    let profile: UserProfile
    /// Chamado depois de salvar, com a mudança nas metas (se houver) para mostrar o aviso.
    let onSaved: (GoalChange?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var date = Date.now

    init(profile: UserProfile, onSaved: @escaping (GoalChange?) -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        // Começa com o peso atual, para só ajustar
        _weightText = State(initialValue: NumberParser.format(profile.weightKg))
    }

    private var weight: Double? { NumericField.weight.value(from: weightText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NumberField(field: .weight, text: $weightText, placeholder: "75")
                    DatePicker("Data", selection: $date, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    Text("Pese-se de preferência no mesmo horário, em jejum. Se já houver um registro nesse dia, ele será substituído.")
                }

                if let weight {
                    Section {
                        LabeledContent("Variação", value: (weight - profile.weightKg).signedKgText)
                    } footer: {
                        Text("Em relação ao peso atual do perfil (\(profile.weightKg.kgText)).")
                    }
                }
            }
            .keyboardDoneButton()
            .navigationTitle("Registrar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        guard let weight else { return }
                        let change = WeightStore.record(weightKg: weight, on: date, profile: profile, in: context)
                        onSaved(change)
                        dismiss()
                    }
                    .disabled(weight == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
