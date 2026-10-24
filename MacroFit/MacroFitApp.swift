import SwiftData
import SwiftUI

@main
struct MacroFitApp: App {
    /// Banco local do SwiftData com os dois modelos do app.
    private let container: ModelContainer
    /// Cor de destaque escolhida no Perfil.
    @State private var themeStore = ThemeStore.makeForApp()

    init() {
        #if DEBUG
        if DemoData.isEnabled {
            container = DemoData.makeContainer()
            return
        }
        #endif
        do {
            container = try ModelContainer(for: Schema(MacroFitSchema.models))
        } catch {
            fatalError("Não foi possível abrir o banco de dados: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchContainerView()
                .environment(themeStore)
                .tint(themeStore.theme.accent)
                .environment(\.accentForeground, themeStore.theme.accentForeground)
        }
        .modelContainer(container)
    }
}
