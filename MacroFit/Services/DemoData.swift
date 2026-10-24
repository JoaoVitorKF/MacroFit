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
///   xcrun simctl launch booted com.joaovitor.macrofit -demo -demo-tab 1 -demo-form → abre o formulário de refeição
///   xcrun simctl launch booted com.joaovitor.macrofit -demo-over             → como -demo, mas com a meta estourada
///   xcrun simctl launch booted com.joaovitor.macrofit -demo -demo-tab 2 -demo-weight → abre a evolução do peso
///   xcrun simctl launch booted com.joaovitor.macrofit -demo -demo-plan "2 ovos e pão" → abre o "O que vou comer?"
enum DemoData {
    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return ["-demo", "-demo-onboarding", "-demo-floor", "-demo-over"].contains { arguments.contains($0) }
    }

    /// Aba inicial (`-demo-tab 2` abre o Perfil). Útil para tirar prints sem tocar na tela.
    static var initialTab: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo-tab"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    /// `-demo-form` abre o formulário de nova refeição ao entrar na aba (para prints).
    static var opensMealForm: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-form")
    }

    /// `-demo-weight` abre a tela de evolução do peso ao entrar no Perfil (para prints).
    static var opensWeightHistory: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-weight")
    }

    /// `-demo-plan "arroz e frango"` abre o "O que vou comer?" com esse texto (para prints).
    static var planText: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-demo-plan"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private static var withSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo") || ProcessInfo.processInfo.arguments.contains("-demo-over")
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: configuration)
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
        // Histórico mais antigo (2 a 6 dias atrás) com repetições, para o "Adicionar rápido" ter frequentes.
        // Não usa ontem nem hoje, para não mudar os totais que os testes de interface conferem.
        let history: [(String, MealType, Double, Double, Double, Double, [Int])] = [
            ("Iogurte com whey", .snack, 260, 35, 18, 5, [2, 3, 4, 6]),
            ("Frango grelhado, arroz e feijão", .lunch, 650, 52, 70, 14, [2, 4, 5]),
            ("Ovos mexidos com pão integral", .breakfast, 420, 28, 35, 18, [3, 5]),
            ("Banana com pasta de amendoim", .snack, 290, 8, 32, 16, [2, 6]),
        ]
        for (name, type, kcal, protein, carbs, fat, daysAgo) in history {
            for offset in daysAgo {
                let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
                let meal = Meal(name: name, type: type, day: day, calories: kcal, protein: protein, carbs: carbs, fat: fat)
                meal.createdAt = day.addingTimeInterval(12 * 3600)
                context.insert(meal)
            }
        }
        // Peso a cada 3 dias nos últimos 60 dias: de ~82,5 kg até 80 kg hoje, com pequenas oscilações
        for step in 0...20 {
            let day = Calendar.current.date(byAdding: .day, value: -3 * (20 - step), to: today) ?? today
            let trend = 82.5 - 0.125 * Double(step)
            let wobble = step == 20 ? 0 : 0.3 * sin(Double(step) * 1.7)
            let weight = ((trend + wobble) * 10).rounded() / 10
            context.insert(WeightEntry(weightKg: weight, day: day))
        }
        // -demo-over: um jantar exagerado para estourar a meta de calorias e de gordura
        if ProcessInfo.processInfo.arguments.contains("-demo-over") {
            context.insert(Meal(name: "Rodízio de pizza", type: .dinner, day: today, calories: 1400, protein: 50, carbs: 150, fat: 60))
        }
    }
}
#endif
