import SwiftData
import SwiftUI

@main
struct MacroFitApp: App {
    /// Banco local do SwiftData com os dois modelos do app.
    private let container: ModelContainer

    init() {
        #if DEBUG
        if DemoData.isEnabled {
            container = DemoData.makeContainer()
            return
        }
        #endif
        do {
            container = try ModelContainer(for: UserProfile.self, Meal.self)
        } catch {
            fatalError("Não foi possível abrir o banco de dados: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
