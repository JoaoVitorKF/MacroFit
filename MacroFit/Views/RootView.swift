import SwiftData
import SwiftUI

/// Tela raiz: mostra o onboarding até existir um perfil salvo; depois, as abas.
struct RootView: View {
    @Query(sort: \UserProfile.updatedAt) private var profiles: [UserProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if let profile = profiles.first {
                MainTabView(profile: profile)
                    .transition(.opacity)
                    .task {
                        // Perfis criados antes do histórico de peso ganham o primeiro registro
                        WeightStore.ensureInitialEntry(for: profile, in: context)
                    }
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
        .modelContainer(for: MacroFitSchema.models, inMemory: true)
}
