import SwiftData
import SwiftUI

@main
struct MacroFitApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Banco local do SwiftData com os dois modelos do app.
        .modelContainer(for: [UserProfile.self, Meal.self])
    }
}
