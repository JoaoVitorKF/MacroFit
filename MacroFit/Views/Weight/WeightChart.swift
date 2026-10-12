import Charts
import SwiftUI

/// Gráfico de evolução do peso (Swift Charts, nativo da Apple).
/// - Compacto: só a linha, sem eixos (usado no card do Perfil).
/// - Completo: eixos, pontos e seleção — toque ou arraste para ver o peso de cada dia.
struct WeightChart: View {
    let points: [WeightPoint]
    var compact = false

    @State private var selectedDate: Date?

    private var domain: ClosedRange<Double> { WeightLog.yDomain(points) }
    private var selected: WeightPoint? {
        selectedDate.flatMap { WeightLog.nearest(to: $0, in: points) }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                // Área com degradê por baixo da linha
                AreaMark(
                    x: .value("Dia", point.day, unit: .day),
                    yStart: .value("Base", domain.lowerBound),
                    yEnd: .value("Peso", point.weightKg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Dia", point.day, unit: .day),
                    y: .value("Peso", point.weightKg)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: compact ? 2.5 : 3, lineCap: .round))
                .foregroundStyle(Color.accentColor)

                // Pontos: sempre no gráfico completo; no compacto, só se houver um único registro
                if !compact || points.count == 1 {
                    PointMark(
                        x: .value("Dia", point.day, unit: .day),
                        y: .value("Peso", point.weightKg)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(compact ? 40 : 28)
                }
            }

            // Linha vertical e balão no dia selecionado
            if let selected, !compact {
                RuleMark(x: .value("Dia", selected.day, unit: .day))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(selected.weightKg.kgText)
                                .font(.headline.monospacedDigit())
                            Text(selected.day.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }

                PointMark(
                    x: .value("Dia", selected.day, unit: .day),
                    y: .value("Peso", selected.weightKg)
                )
                .foregroundStyle(Color.accentColor)
                .symbolSize(110)
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis {
            if !compact {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                    // Formato curto ("4/10") para o último rótulo não ser cortado na borda
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                }
            }
        }
        .chartYAxis(compact ? .hidden : .automatic)
        .chartXSelection(value: compact ? .constant(nil) : $selectedDate)
        #if DEBUG
        .onAppear {
            // -demo-select: já abre com um dia selecionado, para conferir o balão nos prints
            if !compact, ProcessInfo.processInfo.arguments.contains("-demo-select") {
                selectedDate = Calendar.current.date(byAdding: .day, value: -15, to: .now)
            }
        }
        #endif
        .sensoryFeedback(.selection, trigger: selected?.day)
        .accessibilityLabel("Gráfico de peso")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "Sem registros" }
        return "De \(first.weightKg.kgText) para \(last.weightKg.kgText)"
    }
}

#Preview {
    let points = (0...10).map { i in
        WeightPoint(day: Calendar.current.date(byAdding: .day, value: -3 * (10 - i), to: .now)!, weightKg: 82 - Double(i) * 0.2)
    }
    return VStack(spacing: 30) {
        WeightChart(points: points).frame(height: 220)
        WeightChart(points: points, compact: true).frame(height: 60)
    }
    .padding()
}
