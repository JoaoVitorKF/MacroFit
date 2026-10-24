import SwiftUI

/// Perfil → Cor de destaque: cores prontas, tabela RGB (barra + número para R, G e B, e o código hex)
/// e uma prévia. A cor do modo claro e a do escuro são escolhidas separadamente. As mudanças valem na hora.
struct AccentColorView: View {
    @Environment(ThemeStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    /// Qual modo está sendo editado (começa no modo atual do iPhone).
    @State private var editsDark: Bool?
    @State private var hexText = ""

    private var isDark: Bool { editsDark ?? (colorScheme == .dark) }
    private var color: RGBColor { store.theme.color(isDark: isDark) }

    var body: some View {
        List {
            Section {
                Picker("Modo", selection: Binding(get: { isDark }, set: { editsDark = $0 })) {
                    Text("Modo claro").tag(false)
                    Text("Modo escuro").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("modo-cor")

                AccentPreview(theme: store.theme, isDark: isDark)
                    .listRowInsets(EdgeInsets())
            } footer: {
                Text("A cor de destaque aparece no anel de calorias, nos botões, nos ícones e nas abas. O texto sobre ela fica branco ou preto, o que for mais legível.")
            }

            Section("Cores prontas") {
                presets
            }

            Section {
                ChannelRow(name: "R", label: "Vermelho", tint: .red, value: channel(\.red))
                ChannelRow(name: "G", label: "Verde", tint: .green, value: channel(\.green))
                ChannelRow(name: "B", label: "Azul", tint: .blue, value: channel(\.blue))
                hexRow
            } header: {
                Text("Tabela RGB")
            } footer: {
                contrastNote
            }

            Section {
                Button("Voltar ao roxo e amarelo", role: .destructive) {
                    withAnimation { store.reset() }
                    hexText = store.theme.color(isDark: isDark).hex
                }
                .disabled(store.isStandard)
                .accessibilityIdentifier("restaurar-cores")
            } footer: {
                Text("Padrão: roxo \(AccentTheme.standard.light.hex) no modo claro e amarelo \(AccentTheme.standard.dark.hex) no escuro.")
            }
        }
        .navigationTitle("Cor de destaque")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .onAppear { hexText = color.hex }
        .onChange(of: color) { _, new in hexText = new.hex }
    }

    // MARK: - Partes

    private var presets: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 14) {
            ForEach(AccentTheme.presets, id: \.name) { preset in
                Button {
                    withAnimation { store.set(preset.color, isDark: isDark) }
                } label: {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(preset.color.color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if preset.color == color {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(preset.color.readableForeground.color)
                                }
                            }
                            .overlay(Circle().strokeBorder(.primary.opacity(0.12)))
                        Text(preset.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.name)
                .accessibilityAddTraits(preset.color == color ? .isSelected : [])
                .accessibilityIdentifier("cor-\(preset.name)")
            }
        }
        .padding(.vertical, 6)
    }

    private var hexRow: some View {
        HStack {
            Text("Hex")
                .font(.body.weight(.semibold))
                .frame(width: 34, alignment: .leading)
            TextField("#7040C4", text: $hexText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .submitLabel(.done)
                .onSubmit(applyHex)
                .accessibilityIdentifier("campo-hex")
            if RGBColor(hex: hexText) == nil && !hexText.isEmpty {
                Text("Use 6 dígitos, ex.: #7040C4")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.color)
                    .frame(width: 44, height: 26)
            }
        }
        .onChange(of: hexText) { _, text in
            // Aplica assim que o código fica completo (sem esperar o "OK")
            if let parsed = RGBColor(hex: text), parsed != color, text.filter(\.isHexDigit).count == 6 {
                store.set(parsed, isDark: isDark)
            }
        }
    }

    @ViewBuilder
    private var contrastNote: some View {
        let theme = store.theme
        let foreground = color.readableForeground
        let onAccent = color.contrast(with: foreground)
        let onBackground = theme.backgroundContrast(isDark: isDark)
        VStack(alignment: .leading, spacing: 4) {
            Text("Texto sobre o destaque: \(foreground == .white ? "branco" : "preto") (contraste \(Self.ratio(onAccent)))")
            if onBackground < AccentTheme.minimumContrast {
                Label("Pouco contraste com o fundo \(isDark ? "escuro" : "claro") (\(Self.ratio(onBackground))): ícones e o anel podem ficar difíceis de ver. Tente uma cor mais \(isDark ? "clara" : "escura").", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("aviso-contraste")
            } else {
                Text("Contraste com o fundo: \(Self.ratio(onBackground))")
            }
        }
    }

    private func channel(_ keyPath: WritableKeyPath<RGBColor, Int>) -> Binding<Int> {
        Binding {
            color[keyPath: keyPath]
        } set: { newValue in
            var updated = color
            updated[keyPath: keyPath] = RGBColor.clamp(newValue)
            store.set(updated, isDark: isDark)
        }
    }

    private func applyHex() {
        if let parsed = RGBColor(hex: hexText) {
            store.set(parsed, isDark: isDark)
        }
        hexText = color.hex
    }

    /// "6,5:1".
    private static func ratio(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + ":1"
    }
}

/// Uma linha da tabela RGB: letra, barra de 0 a 255 e o número (que também pode ser digitado).
private struct ChannelRow: View {
    let name: String
    let label: String
    let tint: Color
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.body.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 34, alignment: .leading)
                .accessibilityHidden(true)
            Slider(
                value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }),
                in: 0...255,
                step: 1
            )
            .tint(tint)
            .accessibilityLabel(label)
            .accessibilityValue("\(value)")
            .accessibilityIdentifier("barra-\(name)")
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 48)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(label), de 0 a 255")
                .accessibilityIdentifier("valor-\(name)")
        }
    }
}

/// Prévia do destaque no modo escolhido: anel, botão cheio, ícones e barra, sobre o fundo de verdade.
private struct AccentPreview: View {
    let theme: AccentTheme
    let isDark: Bool

    var body: some View {
        let accent = theme.color(isDark: isDark)
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(accent.color.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(accent.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "flame.fill")
                    .foregroundStyle(accent.color)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 10) {
                Label("Adicionar refeição", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent.readableForeground.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(accent.color, in: Capsule())
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                    Image(systemName: "fork.knife")
                    Image(systemName: "chevron.right")
                    ProgressView(value: 0.6)
                        .tint(accent.color)
                }
                .foregroundStyle(accent.color)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .environment(\.colorScheme, isDark ? .dark : .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prévia da cor \(accent.hex) no modo \(isDark ? "escuro" : "claro")")
        .accessibilityIdentifier("previa-cor")
    }
}
