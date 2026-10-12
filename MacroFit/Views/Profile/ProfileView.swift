import SwiftData
import SwiftUI

/// Aba Perfil: metas calculadas, peso (com gráfico) e dados do usuário, com edição em uma folha (sheet).
struct ProfileView: View {
    let profile: UserProfile
    @State private var isEditing = false
    /// Mudança nas metas causada pelo último peso registrado (mostra o aviso no topo).
    @State private var goalChange: GoalChange?
    @State private var showsWeightHistory = false

    var body: some View {
        NavigationStack {
            List {
                Section("Suas metas diárias") {
                    GoalsSummaryView(targets: profile.targets, sex: profile.sex, goal: profile.goal)
                }

                Section("Peso") {
                    // O aviso fica junto do card (onde o usuário acabou de tocar), não no topo da tela
                    if let goalChange {
                        GoalChangeBanner(change: goalChange) {
                            withAnimation { self.goalChange = nil }
                        }
                    }
                    WeightCard(profile: profile) { change in
                        withAnimation { goalChange = change }
                    }
                    NavigationLink {
                        WeightHistoryView(profile: profile)
                    } label: {
                        Label("Ver evolução", systemImage: "chart.xyaxis.line")
                    }
                }

                Section("Seus dados") {
                    LabeledContent("Sexo biológico", value: profile.sex.displayName)
                    LabeledContent("Idade", value: "\(profile.age) anos")
                    LabeledContent("Peso", value: "\(NumberParser.format(profile.weightKg)) kg")
                    LabeledContent("Altura", value: "\(NumberParser.format(profile.heightCm)) cm")
                    LabeledContent("Atividade", value: "\(profile.activity.displayName) (×\(profile.activity.factor.formatted()))")
                    LabeledContent("Objetivo", value: profile.goal.displayName)
                }

                Section {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Editar dados", systemImage: "pencil")
                    }
                } footer: {
                    Text("As metas usam o peso mais recente registrado. Registre o peso de tempos em tempos para elas acompanharem sua evolução.")
                }
            }
            .navigationTitle("Perfil")
            .toolbar {
                Button("Editar") { isEditing = true }
            }
            .sheet(isPresented: $isEditing) {
                ProfileEditSheet(profile: profile)
            }
            .navigationDestination(isPresented: $showsWeightHistory) {
                WeightHistoryView(profile: profile)
            }
            #if DEBUG
            .onAppear {
                if DemoData.opensWeightHistory { showsWeightHistory = true }
            }
            #endif
        }
    }
}

/// Folha de edição do perfil. Só grava ao tocar em "Salvar"; "Cancelar" descarta as mudanças.
private struct ProfileEditSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileViewModel

    init(profile: UserProfile) {
        self.profile = profile
        _viewModel = State(initialValue: ProfileViewModel(profile: profile))
    }

    var body: some View {
        NavigationStack {
            ProfileFormView(viewModel: viewModel)
                .navigationTitle("Editar perfil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Salvar") {
                            if viewModel.save(to: profile, in: context) {
                                dismiss()
                            }
                        }
                        .disabled(!viewModel.isValid)
                    }
                }
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    ProfileView(profile: UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate))
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
