import SwiftUI

/// Card "O que vai comer?" da tela Hoje: escreva ou dite os alimentos e veja quantos gramas cabem.
struct WhatToEatCard: View {
    let onSubmit: (String) -> Void
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("O que vai comer?")
            } icon: {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            .font(.headline)

            HStack(spacing: 8) {
                TextField("Ex.: arroz, feijão e frango", text: $text)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .accessibilityIdentifier("campo-o-que-comer")

                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                }
                .disabled(isEmpty)
                .accessibilityLabel("Ver quantos gramas posso comer")
                .accessibilityIdentifier("ver-gramas")
            }

            Text("Escreva ou toque no microfone do teclado e fale. Eu digo quantos gramas cabem.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    private func submit() {
        guard !isEmpty else { return }
        onSubmit(text.trimmingCharacters(in: .whitespaces))
        text = ""
        isFocused = false
    }
}
