import SwiftUI

/// As três abas do app.
struct MainTabView: View {
    let profile: UserProfile
    @State private var selectedTab = MainTabView.initialTab

    var body: some View {
        TabView(selection: $selectedTab) {
            PlaceholderTab(title: "Hoje", symbol: "chart.pie")
                .tabItem { Label("Hoje", systemImage: "chart.pie.fill") }
                .tag(0)

            PlaceholderTab(title: "Refeições", symbol: "fork.knife")
                .tabItem { Label("Refeições", systemImage: "fork.knife") }
                .tag(1)

            ProfileView(profile: profile)
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
                .tag(2)
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

/// Provisório até as próximas etapas.
private struct PlaceholderTab: View {
    let title: String
    let symbol: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text("Em construção."))
    }
}
