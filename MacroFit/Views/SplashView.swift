import SwiftUI

/// Tela de carregamento mostrada ao abrir o app: um anel que se preenche (como o de calorias),
/// o ícone e o nome. Dura cerca de 1,5 s e depois chama `onFinish`.
/// Com "Reduzir Movimento" ativado no iPhone, aparece já completa, sem animação, e some mais rápido.
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringProgress: CGFloat = 0
    @State private var iconScale: CGFloat = 0.6
    @State private var textVisible = false

    var body: some View {
        ZStack {
            // Mesmo fundo da tela de abertura do sistema, para a transição não "piscar"
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "fork.knife")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .scaleEffect(iconScale)
                }
                .frame(width: 120, height: 120)

                VStack(spacing: 6) {
                    Text("MacroFit")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Seu dia em calorias e macros")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MacroFit carregando")
        .task {
            await animate()
            onFinish()
        }
    }

    private func animate() async {
        if reduceMotion {
            ringProgress = 1
            iconScale = 1
            textVisible = true
            try? await Task.sleep(for: .milliseconds(600))
            return
        }
        withAnimation(.easeInOut(duration: 0.9)) { ringProgress = 1 }
        withAnimation(.spring(duration: 0.6, bounce: 0.4)) { iconScale = 1 }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) { textVisible = true }
        try? await Task.sleep(for: .milliseconds(1_400))
    }
}

/// Junta a tela de carregamento e o app: o app já é montado por baixo (carregando os dados)
/// enquanto a animação roda por cima; no fim, a tela de carregamento some com um fade.
struct LaunchContainerView: View {
    @State private var showsSplash = !LaunchContainerView.skipsSplash

    var body: some View {
        ZStack {
            RootView()
            if showsSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.35)) { showsSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
                .zIndex(1)
            }
        }
    }

    /// `-skip-splash` pula a tela de carregamento (usado pelos testes de interface).
    private static var skipsSplash: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-skip-splash")
        #else
        return false
        #endif
    }
}

#Preview {
    SplashView {}
}
