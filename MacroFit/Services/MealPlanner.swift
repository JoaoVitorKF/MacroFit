import Foundation

/// "Quanto posso comer?": quanto sobra para uma refeição e quantos gramas de cada alimento cabem nisso.
/// Funções puras, testáveis.
enum MealPlanner {

    /// Peso de cada refeição na divisão do dia.
    static let shares: [MealType: Double] = [
        .breakfast: 0.25,
        .lunch: 0.35,
        .snack: 0.15,
        .dinner: 0.25,
    ]

    /// Limites de cada alimento numa sugestão (em gramas).
    static let minGrams = 20.0
    static let maxGrams = 600.0
    /// Arredondamento das sugestões.
    static let step = 5.0

    // MARK: - Orçamento da refeição

    /// Quanto sobra para esta refeição: o que falta no dia (meta − outras refeições do dia), dividido
    /// proporcionalmente entre esta refeição e as que ainda não foram registradas.
    /// - Parameters:
    ///   - consumedByOthers: total das **outras** refeições do dia (ao editar, sem contar a própria).
    ///   - loggedTypes: tipos de refeição que já têm algo registrado no dia (fora esta).
    static func budget(
        targets: NutritionTargets,
        consumedByOthers: Macros,
        loggedTypes: Set<MealType>,
        for type: MealType
    ) -> Macros {
        let remaining = Macros(
            calories: max(targets.calories - consumedByOthers.calories, 0),
            protein: max(targets.protein - consumedByOthers.protein, 0),
            carbs: max(targets.carbs - consumedByOthers.carbs, 0),
            fat: max(targets.fat - consumedByOthers.fat, 0)
        )
        // Refeições ainda por fazer: as não registradas + esta (mesmo que já tenha outra do mesmo tipo)
        var pending = Set(MealType.allCases).subtracting(loggedTypes)
        pending.insert(type)
        let totalShare = pending.reduce(0) { $0 + (shares[$1] ?? 0) }
        let fraction = totalShare > 0 ? (shares[type] ?? 0) / totalShare : 1
        return remaining.scaled(by: fraction)
    }

    // MARK: - Sugestão de gramas

    /// Gramas de cada alimento para chegar o mais perto possível das calorias, proteína, carboidrato e
    /// gordura do orçamento, **sem passar das calorias** dele. Arredonda de 5 em 5 g, entre 20 e 600 g.
    ///
    /// Como funciona: mínimos quadrados com limites, resolvidos por descida por coordenadas (cada alimento
    /// é ajustado de forma exata, um de cada vez, até estabilizar). O erro de cada item é medido em
    /// proporção à meta; calorias e proteína pesam mais (energia do dia e foco da recomposição). Um termo
    /// puxa cada alimento para perto de uma porção normal (100 g): alimentos quase sem calorias (alface)
    /// não viram quantidades absurdas e um alimento escolhido não some. No fim, se passar das calorias,
    /// reduz tudo na mesma proporção.
    static func suggestGrams(for foods: [Macros], budget: Macros) -> [Double] {
        guard !foods.isEmpty else { return [] }
        guard budget.calories > 1 else { return foods.map { _ in minGrams } }

        let target = [budget.calories, budget.protein, budget.carbs, budget.fat]
        let weights = [3.0, 2.0, 0.6, 0.6]
        // Escala: erros em proporção à meta (mínimos para não dividir por ~0)
        let scale = [max(budget.calories, 100), max(budget.protein, 10), max(budget.carbs, 10), max(budget.fat, 10)]
        let reference = 100.0
        let regularization = regularizationWeight / (reference * reference)

        // Coeficientes normalizados: quanto 1 g de cada alimento contribui para cada item (÷ escala)
        let a = foods.map { food in
            [food.calories / 100 / scale[0], food.protein / 100 / scale[1], food.carbs / 100 / scale[2], food.fat / 100 / scale[3]]
        }
        let t = (0..<4).map { target[$0] / scale[$0] }
        let n = foods.count

        // Forma quadrática: f(g) = gᵀHg − 2bᵀg + constante
        var h = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        var b = [Double](repeating: 0, count: n)
        for i in 0..<n {
            for j in 0..<n {
                h[i][j] = (0..<4).reduce(0) { $0 + weights[$1] * a[i][$1] * a[j][$1] }
            }
            h[i][i] += regularization
            b[i] = (0..<4).reduce(0) { $0 + weights[$1] * a[i][$1] * t[$1] } + regularization * reference
        }

        // Porção mínima de cada alimento escolhido: ~15% das calorias da refeição, entre 20 e 100 g
        // (quem escolheu banana no lanche quer uma banana, não 20 g dela)
        let lowerBounds = foods.map { food -> Double in
            guard food.calories > 0 else { return minGrams }
            let gramsForShare = minimumCalorieShare * budget.calories / (food.calories / 100)
            return min(max(gramsForShare, minGrams), reference)
        }

        var grams = [Double](repeating: reference, count: n)
        for _ in 0..<500 {
            var change = 0.0
            for i in 0..<n {
                var rest = b[i]
                for j in 0..<n where j != i { rest -= h[i][j] * grams[j] }
                let best = min(max(rest / h[i][i], lowerBounds[i]), maxGrams)
                change = max(change, abs(best - grams[i]))
                grams[i] = best
            }
            if change < 0.01 { break }
        }

        // Não passar das calorias do orçamento
        let kcal = zip(foods, grams).reduce(0) { $0 + $1.0.calories * $1.1 / 100 }
        if kcal > budget.calories {
            let factor = budget.calories / kcal
            grams = grams.map { max($0 * factor, minGrams) }
        }

        // Arredonda para baixo de 5 em 5 g (arredondar para cima poderia passar das calorias)
        return grams.map { max((($0 / step).rounded(.down)) * step, minGrams) }
    }

    /// Força com que cada alimento é puxado para 100 g. Fraca: só evita que alimentos quase sem
    /// calorias (alface) disparem; o resto é decidido pelas metas.
    static let regularizationWeight = 0.01
    /// Fração das calorias da refeição que define a porção mínima de cada alimento escolhido.
    static let minimumCalorieShare = 0.15

    /// Calorias e macros de uma lista de alimentos com os gramas indicados.
    static func total(of foods: [Macros], grams: [Double]) -> Macros {
        zip(foods, grams).map { $0.scaled(by: $1 / 100) }.total()
    }
}
