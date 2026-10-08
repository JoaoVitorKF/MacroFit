import SwiftUI

/// As três abas do app.
struct MainTabView: View {
    let profile: UserProfile
    @State private var selectedTab = MainTabView.initialTab
    /// Dia selecionado, compartilhado entre Hoje e Refeições.
    @State private var daySelection = DaySelection()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(profile: profile)
                .tabItem { Label("Hoje", systemImage: "chart.pie.fill") }
                .tag(0)

            MealsView()
                .tabItem { Label("Refeições", systemImage: "fork.knife") }
                .tag(1)

            ProfileView(profile: profile)
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(2)
        }
        .environment(daySelection)
        .onChange(of: scenePhase) { _, phase in
            // Ao voltar para o app depois da meia-noite, "hoje" passa a ser o novo dia
            if phase == .active {
                daySelection.refreshIfDayChanged()
            }
        }
    }

    private static var initialTab: Int {
        #if DEBUG
        return DemoData.initialTab ?? 0
        #else
        return 0
        #endif
    }
}
