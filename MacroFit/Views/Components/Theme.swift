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

    var symbol: String {
        switch self {
        case .calories: "flame.fill"
        case .protein: "bolt.heart.fill"
        case .carbs: "leaf.fill"
        case .fat: "drop.fill"
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

extension Color {
    /// Cor do texto e dos ícones **sobre** o destaque (botões cheios): branco sobre o roxo do
    /// modo claro, preto sobre o amarelo do modo escuro (branco sobre amarelo ficaria ilegível).
    static let accentForeground = Color("AccentForeground")
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
