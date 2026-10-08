import SwiftData
import SwiftUI

/// Tela raiz: mostra o onboarding até existir um perfil salvo; depois, as abas.
struct RootView: View {
    @Query(sort: \UserProfile.updatedAt) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: profiles.isEmpty)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [UserProfile.self, Meal.self], inMemory: true)
}
