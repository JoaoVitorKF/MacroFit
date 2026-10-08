import SwiftData
import SwiftUI

/// Primeira tela do app: coleta os dados e cria o perfil.
/// Assim que o perfil é salvo, a `RootView` troca automaticamente para as abas.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ProfileFormView(viewModel: viewModel)
                .navigationTitle("Bem-vindo ao MacroFit")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top) {
                    Text("Conte um pouco sobre você para calcularmos suas calorias e macros do dia.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        viewModel.save(to: nil, in: context)
                    } label: {
                        Text("Começar")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.isValid)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.bar)
                }
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, Meal.self], inMemory: true)
}
