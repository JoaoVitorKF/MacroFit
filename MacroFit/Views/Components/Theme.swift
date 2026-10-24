import SwiftUI
import UIKit

/// Cores e ícones de cada nutriente, usados de forma consistente em todas as telas.
enum Nutrient: CaseIterable, Identifiable {
    case calories
    case protein
    case carbs
    case fat

    var id: Self { self }

    var name: String {
        switch self {
        case .calories: "Calorias"
        case .protein: "Proteína"
        case .carbs: "Carboidrato"
        case .fat: "Gordura"
        }
    }

    /// Nome curto para espaços apertados.
    var shortName: String {
        switch self {
        case .calories: "Kcal"
        case .protein: "Prot."
        case .carbs: "Carbo"
        case .fat: "Gord."
        }
    }

    var color: Color {
        switch self {
        case .calories: .accentColor
        case .protein: .pink
        case .carbs: .teal
        case .fat: .orange
        }
    }

    /// Ícone do nutriente. O SF Symbols não tem carne nem feijão, então proteína e carboidrato
    /// usam os emojis da Apple (coloridos e iguais em qualquer iPhone); os demais são SF Symbols.
    var icon: NutrientIcon {
        switch self {
        case .calories: .symbol("flame.fill")
        case .protein: .emoji("🥩")
        case .carbs: .emoji("🫘")
        case .fat: .symbol("bolt.heart.fill")
        }
    }

    /// Valor deste nutriente dentro de um `Macros`.
    func value(in macros: Macros) -> Double {
        switch self {
        case .calories: macros.calories
        case .protein: macros.protein
        case .carbs: macros.carbs
        case .fat: macros.fat
        }
    }
}

/// Cor do texto e dos ícones **sobre** o destaque (botões cheios): branco ou preto, o mais legível
/// sobre a cor escolhida no Perfil (branco sobre o roxo, preto sobre o amarelo). Vem do ambiente,
/// que a `MacroFitApp` preenche com o `ThemeStore`. Uso: `.foregroundStyle(.accentForeground)`.
struct AccentForegroundStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.accentForeground
    }
}

extension ShapeStyle where Self == AccentForegroundStyle {
    static var accentForeground: AccentForegroundStyle { AccentForegroundStyle() }
}

private struct AccentForegroundKey: EnvironmentKey {
    static let defaultValue = AccentTheme.standard.accentForeground
}

extension EnvironmentValues {
    var accentForeground: Color {
        get { self[AccentForegroundKey.self] }
        set { self[AccentForegroundKey.self] = newValue }
    }
}

enum NutrientIcon {
    case symbol(String)
    case emoji(String)
}

/// Desenha o ícone do nutriente: SF Symbol pintado com a cor do nutriente, ou o emoji como é.
/// Segue a fonte de onde estiver (`.font`), então fica do mesmo tamanho do texto ao lado.
struct NutrientIconView: View {
    let nutrient: Nutrient

    var body: some View {
        switch nutrient.icon {
        case .symbol(let name):
            Image(systemName: name)
                .foregroundStyle(nutrient.color)
        case .emoji(let emoji):
            Text(emoji)
                .accessibilityHidden(true)
        }
    }
}

/// Card arredondado padrão do app. Funciona em modo claro e escuro.
struct CardModifier: ViewModifier {
    /// Margem interna do card (usada também por conteúdos que rolam de borda a borda).
    static let padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(Self.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View {
        modifier(CardModifier())
    }
}

/// Fecha o teclado (usado no botão "OK" acima dos teclados numéricos, que não têm "Enter").
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
