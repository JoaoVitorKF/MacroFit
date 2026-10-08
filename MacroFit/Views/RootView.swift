import SwiftUI

/// Tela raiz. Provisória na Etapa 1; nas próximas etapas decide entre onboarding e abas.
struct RootView: View {
    var body: some View {
        ContentUnavailableView(
            "MacroFit",
            systemImage: "fork.knife.circle",
            description: Text("Em construção.")
        )
    }
}

#Preview {
    RootView()
}
