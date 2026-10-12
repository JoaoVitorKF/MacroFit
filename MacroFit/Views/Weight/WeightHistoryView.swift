import SwiftData
import SwiftUI

/// Card de peso da aba Perfil: peso atual, variação em 30 dias, mini gráfico e ações.
struct WeightCard: View {
    let profile: UserProfile
    /// Repassa a mudança nas metas para a tela mostrar o aviso.
    let onGoalChange: (GoalChange?) -> Void

    @Query(sort: \WeightEntry.day) private var entries: [WeightEntry]
    @State private var isRecording = false

    private var monthPoints: [WeightPoint] {
        WeightLog.filter(WeightLog.points(from: entries), period: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Peso atual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(profile.weightKg.kgText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
                Spacer()
                if let change = WeightLog.change(monthPoints) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(change.signedKgText)
                            .font(.headline.monospacedDigit())
                        Text("em 30 dias")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !monthPoints.isEmpty {
                WeightChart(points: monthPoints, compact: true)
                    .frame(height: 60)
            }

            Button {
                isRecording = true
            } label: {
                Label("Registrar peso", systemImage: "scalemass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isRecording) {
            WeightEntrySheet(profile: profile, onSaved: onGoalChange)
        }
    }
}

/// Tela de evolução do peso: gráfico com período, resumo e lista de registros (deslize para apagar).
struct WeightHistoryView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.day, order: .reverse) private var entries: [WeightEntry]
    @State private var period: WeightPeriod = .quarter
    @State private var isRecording = false
    @State private var goalChange: GoalChange?

    private var points: [WeightPoint] {
        WeightLog.filter(WeightLog.points(from: entries), period: period)
    }

    var body: some View {
        List {
            if let goalChange {
                Section {
                    GoalChangeBanner(change: goalChange) {
                        withAnimation { self.goalChange = nil }
                    }
                }
            }

            Section {
                Picker("Período", selection: $period) {
                    ForEach(WeightPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if points.isEmpty {
                    ContentUnavailableView("Sem registros no período", systemImage: "chart.xyaxis.line")
                } else {
                    WeightChart(points: points)
                        .frame(height: 240)
                        .padding(.top, 28) // espaço para o balão do ponto selecionado
                    summary
                }
            } footer: {
                if !points.isEmpty {
                    Text("Toque ou arraste no gráfico para ver o peso de cada dia.")
                }
            }

            Section("Registros") {
                ForEach(entries) { entry in
                    LabeledContent {
                        Text(entry.weightKg.kgText)
                            .monospacedDigit()
                    } label: {
                        Text(entry.day.formatted(date: .abbreviated, time: .omitted))
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            let change = WeightStore.delete(entry, profile: profile, in: context)
                            withAnimation { goalChange = change ?? goalChange }
                        } label: {
                            Label("Apagar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Evolução do peso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                isRecording = true
            } label: {
                Label("Registrar peso", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isRecording) {
            WeightEntrySheet(profile: profile) { change in
                withAnimation { goalChange = change }
            }
        }
        .animation(.default, value: period)
    }

    /// Peso inicial, atual e variação no período escolhido.
    private var summary: some View {
        HStack {
            stat("Início", points.first?.weightKg.kgText ?? "–")
            Divider().frame(height: 30)
            stat("Atual", points.last?.weightKg.kgText ?? "–")
            Divider().frame(height: 30)
            stat("Variação", WeightLog.change(points)?.signedKgText ?? "–")
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}
