import SwiftUI

/// As três abas do app.
struct MainTabView: View {
    let profile: UserProfile
    @State private var selectedTab = MainTabView.initialTab
    /// Dia selecionado, compartilhado entre Hoje e Refeições.
    @State private var daySelection = DaySelection()
    /// Comemorações ao bater metas (aviso + confete por cima de qualquer aba).
    @State private var celebrations = CelebrationCenter()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(profile: profile)
                .tabItem { Label("Hoje", systemImage: "chart.pie.fill") }
                .tag(0)

            MealsView()
                .tabItem { Label("Refeições", systemImage: "fork.knife") }
                .tag(1)

            ProfileView(profile: profile)
                .tabItem {
                    Label {
                        Text("Perfil")
                    } icon: {
                        profileIcon
                    }
                }
                .tag(2)
        }
        .environment(daySelection)
        .environment(celebrations)
        .background(CelebrationWatcher(targets: profile.targets).environment(celebrations))
        .overlay(alignment: .top) {
            CelebrationOverlay().environment(celebrations)
        }
        .onChange(of: scenePhase) { _, phase in
            // Ao voltar para o app depois da meia-noite, "hoje" passa a ser o novo dia
            if phase == .active {
                daySelection.refreshIfDayChanged()
                EnergyStore.refresh(profile, in: context)
            }
        }
    }

    /// A foto do perfil, redonda, ou o boneco do sistema quando não há foto.
    private var profileIcon: Image {
        if let data = profile.photoData, let icon = ProfilePhoto.tabIcon(from: data) {
            return Image(uiImage: icon)
        }
        return Image(systemName: "person.crop.circle")
    }

    private static var initialTab: Int {
        #if DEBUG
        return DemoData.initialTab ?? 0
        #else
        return 0
        #endif
    }
}
