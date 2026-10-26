import SwiftUI

/// Seção "Gasto real" do Perfil: o gasto estimado pelo que a pessoa comeu e pesou nos últimos 28 dias
/// (`EnergyBalance`), comparado com a fórmula, e a chave para usá-lo nas metas. Sem dados suficientes,
/// mostra quanto falta.
struct EnergySection: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var result: EnergyBalance.Result?

    var body: some View {
        Section {
            switch result {
            case .ready(let estimate):
                ready(estimate)
            case .needsMoreData(let loggedDays, let weighIns, let spanDays):
                needsMoreData(loggedDays: loggedDays, weighIns: weighIns, spanDays: spanDays)
            case nil:
                ProgressView()
            }
        } header: {
            Text("Gasto real")
        } footer: {
            Text("Fórmulas erram uns 10% para cada pessoa. Com o que você registra de comida e de peso, o app mede o seu gasto de verdade: média do que comeu + o que o peso mudou (≈ 7.700 kcal por kg). Dias com menos de \(EnergyBalance.minimumDayKcal.kcalText) kcal registradas contam como esquecidos.")
        }
        .task {
            result = EnergyStore.refresh(profile, in: context)
        }
    }

    @ViewBuilder
    private func ready(_ estimate: EnergyBalance.Estimate) -> some View {
        let formula = NutritionCalculator.targets(for: profile.formulaInput).tdee
        VStack(alignment: .leading, spacing: 2) {
            Text("Pelos seus registros")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(estimate.measuredTdee.kcalText)
                    .font(.title.bold().monospacedDigit())
                Text("kcal/dia")
                    .foregroundStyle(.secondary)
            }
            Text("A fórmula estimava \(formula.kcalText) kcal (\((estimate.measuredTdee - formula).signedKcalText)).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gasto-medido")

        LabeledContent("Média registrada", value: "\(estimate.averageIntake.kcalText) kcal em \(estimate.loggedDays) dias")
        LabeledContent("Tendência do peso", value: "\(estimate.weeklyTrendKg.signedPreciseKgText) por semana")
        LabeledContent("Usado nas metas", value: "\(estimate.tdee.kcalText) kcal")

        Toggle("Usar o gasto real nas metas", isOn: $profile.usesMeasuredTdee)
            .accessibilityIdentifier("usar-gasto-real")
            .onChange(of: profile.usesMeasuredTdee) { try? context.save() }

        VStack(alignment: .leading, spacing: 4) {
            Text("Usado nas metas = \(Int((estimate.confidence * 100).rounded()))% medido + \(Int(((1 - estimate.confidence) * 100).rounded()))% fórmula. Com 28 dias registrados, vale só o medido.")
            if estimate.wasClamped {
                Text("O valor medido passou de 25% de diferença da fórmula e foi limitado. Confira se todos os dias estão registrados por completo.")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func needsMoreData(loggedDays: Int, weighIns: Int, spanDays: Int) -> some View {
        Label("Ainda juntando dados para medir o seu gasto", systemImage: "hourglass")
            .font(.subheadline.weight(.semibold))
            .accessibilityIdentifier("gasto-faltam-dados")
        requirement("Dias com refeições registradas", have: loggedDays, need: EnergyBalance.minimumLoggedDays)
        requirement("Pesagens", have: weighIns, need: EnergyBalance.minimumWeighIns)
        requirement("Dias entre a 1ª e a última pesagem", have: spanDays, need: EnergyBalance.minimumSpanDays)
        Text("Tudo dentro dos últimos \(EnergyBalance.windowDays) dias. Até lá, as metas usam a fórmula.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func requirement(_ title: String, have: Int, need: Int) -> some View {
        let done = have >= need
        return LabeledContent {
            Text("\(min(have, need)) de \(need)")
                .monospacedDigit()
                .foregroundStyle(done ? Color.accentColor : .secondary)
        } label: {
            Label(title, systemImage: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(.primary)
        }
    }
}
