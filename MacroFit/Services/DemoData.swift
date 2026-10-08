#if DEBUG
import Foundation
import SwiftData

/// Dados de exemplo para desenvolvimento, ativados pelo argumento de lançamento `-demo`.
/// Usam um banco **em memória**: nada é gravado e os dados reais do app não são tocados.
/// Só existe em builds Debug; não vai para o app instalado no modo Release.
///
/// Exemplos:
///   xcrun simctl launch booted com.joaovitor.macrofit -demo              → perfil + refeições de hoje e ontem
///   xcrun simctl launch booted com.joaovitor.macrofit -demo-onboarding   → banco vazio (tela de boas-vindas)
///   xcrun simctl launch booted com.joaovitor.macrofit -demo -demo-tab 2  → abre direto na aba Perfil
///   xcrun simctl launch booted com.joaovitor.macrofit -demo-floor -demo-tab 2 → perfil que cai no piso de calorias
enum DemoData {
    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-demo") || arguments.contains("-demo-onboarding") || arguments.contains("-demo-floor")
    }

    /// Aba inicial (`-demo-tab 2` abre o Perfil). Útil para tirar prints sem tocar na tela.
    static var initialTab: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo-tab"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    private static var withSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: UserProfile.self, Meal.self, configurations: configuration)
            if withSampleData {
                insertSamples(into: container.mainContext)
            } else if ProcessInfo.processInfo.arguments.contains("-demo-floor") {
                // Perfil cuja meta cai abaixo do piso de 1200 kcal (mostra o aviso)
                container.mainContext.insert(UserProfile(sex: .female, age: 70, weightKg: 40, heightCm: 140, activity: .sedentary, goal: .loseFat))
            }
            return container
        } catch {
            fatalError("Não foi possível criar o banco de demonstração: \(error)")
        }
    }

    @MainActor
    private static func insertSamples(into context: ModelContext) {
        context.insert(UserProfile(sex: .male, age: 30, weightKg: 80, heightCm: 180, activity: .moderate))

        let today = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today

        let samples: [(String, MealType, Date, Double, Double, Double, Double)] = [
            ("Ovos mexidos com pão integral", .breakfast, today, 420, 28, 35, 18),
            ("Frango grelhado, arroz e feijão", .lunch, today, 650, 52, 70, 14),
            ("Iogurte com whey", .snack, today, 260, 35, 18, 5),
            ("Aveia com banana", .breakfast, yesterday, 380, 14, 62, 8),
            ("Carne moída com batata-doce", .lunch, yesterday, 720, 48, 66, 26),
            ("Omelete de queijo", .dinner, yesterday, 450, 30, 4, 34),
        ]
        for (name, type, day, kcal, protein, carbs, fat) in samples {
            context.insert(Meal(name: name, type: type, day: day, calories: kcal, protein: protein, carbs: carbs, fat: fat))
        }
    }
}
#endif
