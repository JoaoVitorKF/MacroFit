import SwiftUI

/// Seletor de dia: ‹ dia anterior | título (abre calendário) | próximo dia ›.
struct DaySelector: View {
    @Environment(DaySelection.self) private var selection
    @State private var showsCalendar = false

    var body: some View {
        VStack(spacing: 4) {
            arrows
            // Atalho para voltar a hoje quando estiver em outro dia
            if !selection.isToday {
                Button {
                    selection.goToToday()
                } label: {
                    Label("Voltar para hoje", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
            }
        }
        .animation(.snappy, value: selection.isToday)
        .sheet(isPresented: $showsCalendar) {
            CalendarSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var arrows: some View {
        HStack {
            Button {
                selection.move(byDays: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            // Estilo explícito em cada botão: numa linha de List, botões com o estilo padrão
            // viram um só e o toque dispara todos eles ao mesmo tempo.
            .buttonStyle(.borderless)
            .accessibilityLabel("Dia anterior")

            Spacer()

            Button {
                showsCalendar = true
            } label: {
                VStack(spacing: 0) {
                    Text(selection.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(selection.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Abre o calendário")

            Spacer()

            Button {
                selection.move(byDays: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Próximo dia")
        }
        .font(.body.weight(.semibold))
    }
}

/// Calendário para pular para qualquer data.
private struct CalendarSheet: View {
    @Environment(DaySelection.self) private var selection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Dia",
                selection: Binding(get: { selection.day }, set: { selection.select($0); dismiss() }),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("Escolher dia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hoje") {
                        selection.goToToday()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DaySelector()
        .padding()
        .environment(DaySelection())
}
