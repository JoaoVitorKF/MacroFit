import SwiftUI

/// Formulário de dados pessoais, compartilhado entre o onboarding e a edição do perfil.
/// Mostra as metas sendo recalculadas ao vivo no final.
struct ProfileFormView: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section("Sobre você") {
                Picker("Sexo biológico", selection: $viewModel.sex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                NumberField(field: .age, text: $viewModel.ageText, placeholder: "30")
                NumberField(field: .weight, text: $viewModel.weightText, placeholder: "75")
                NumberField(field: .height, text: $viewModel.heightText, placeholder: "175")
            }

            Section {
                NavigationLink {
                    ActivityPickerView(selection: $viewModel.activity)
                } label: {
                    LabeledContent {
                        Text(viewModel.activity.displayName)
                    } label: {
                        Label("Nível de atividade", systemImage: "figure.run")
                    }
                }
            } header: {
                Text("Atividade")
            } footer: {
                Text("\(viewModel.activity.detail) · fator \(viewModel.activity.factor.formatted())")
            }

            Section {
                ForEach(Goal.allCases) { goal in
                    GoalRow(goal: goal, isSelected: viewModel.goal == goal) {
                        withAnimation { viewModel.goal = goal }
                    }
                }
                if viewModel.goal == .loseFat {
                    Picker("Ritmo", selection: $viewModel.pace) {
                        ForEach(WeightLossPace.allCases) { pace in
                            Text(pace.displayName).tag(pace)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("ritmo")
                }
            } header: {
                Text("Objetivo")
            } footer: {
                if viewModel.goal == .loseFat {
                    Text(paceFooter)
                }
            }

            Section("Suas metas diárias") {
                if let targets = viewModel.targets {
                    GoalsSummaryView(targets: targets, sex: viewModel.sex, goal: viewModel.goal, weightKg: viewModel.input?.weightKg ?? 0)
                } else {
                    Label("Preencha idade, peso e altura para ver suas metas.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
    }
}

extension ProfileFormView {
    /// "Moderado: 0,75% do peso por semana (≈ 0,73 kg)". Recomendação usual: 0,5–1% por semana.
    var paceFooter: String {
        var text = "\(viewModel.pace.displayName): \(viewModel.pace.detail)"
        if let weight = viewModel.input?.weightKg {
            text += " (≈ \((weight * viewModel.pace.weeklyFraction).preciseKgText))"
        }
        return text + ". De 0,5% a 1% por semana é a faixa recomendada; mais rápido que isso aumenta a perda de músculo."
    }
}

/// Lista dos níveis de atividade com descrição; tocar num nível seleciona e volta.
private struct ActivityPickerView: View {
    @Binding var selection: ActivityLevel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(ActivityLevel.allCases) { level in
            Button {
                selection = level
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.displayName)
                            .foregroundStyle(.primary)
                        Text("\(level.detail) · fator \(level.factor.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if level == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .fontWeight(.semibold)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Nível de atividade")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Linha selecionável de objetivo, com ícone, descrição e marca de seleção.
private struct GoalRow: View {
    let goal: Goal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: goal.symbol)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .foregroundStyle(.primary)
                    Text(goal.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        ProfileFormView(viewModel: ProfileViewModel())
            .navigationTitle("Perfil")
    }
}
