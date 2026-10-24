import Foundation
import Observation
import SwiftData

/// Estado do formulário de refeição: criar, editar ou repetir uma refeição anterior.
/// Dois modos:
/// - **Por alimentos** (padrão): escolhe alimentos da tabela e digita os gramas; os totais são calculados.
/// - **Digitar valores**: calorias e macros digitados à mão (produtos de rótulo, refeições antigas).
@Observable
final class MealFormViewModel {

    enum EntryMode: Hashable {
        case foods
        case manual
    }

    /// Um alimento no formulário: o item e os gramas como texto (o usuário digita livremente).
    struct ItemDraft: Identifiable, Equatable {
        let id = UUID()
        var item: MealItem
        var gramsText: String
        /// Gramas de referência para o seletor de porção (½×, 2×…).
        var baseGrams: Double
        /// Quantidade decidida pelo usuário ("2 ovos" no texto, ajuste no "O que vou comer?"):
        /// a sugestão de gramas não mexe nela.
        var isLocked = false

        init(item: MealItem) {
            self.item = item
            self.gramsText = NumberParser.format(item.grams)
            self.baseGrams = item.grams
        }

        var grams: Double? { NumericField.grams.value(from: gramsText) }
        var macros: Macros? { grams.map { item.per100g.scaled(by: $0 / 100) } }
    }

    var name: String
    var type: MealType
    var mode: EntryMode
    var items: [ItemDraft] = []
    var caloriesText: String
    var proteinText: String
    var carbsText: String
    var fatText: String

    /// Dia ao qual a refeição pertence.
    let day: Date
    /// Refeição sendo editada (`nil` ao criar).
    let editing: Meal?

    static let maxNameLength = 60
    /// Quantidade sugerida ao adicionar um alimento (o usuário ajusta).
    static let defaultGrams: Double = 100

    /// Valores de referência para o seletor de porção no modo digitado.
    private(set) var portionBase: Macros?
    /// Porção escolhida em relação à referência.
    private(set) var portion: Portion = .one
    /// Mostra o seletor de porção (refeição repetida ou editada).
    private(set) var showsPortion = false

    /// Nova refeição no dia escolhido, por alimentos. Sem tipo informado, sugere um pela hora atual.
    init(day: Date, type: MealType? = nil) {
        self.day = day
        self.editing = nil
        name = ""
        self.type = type ?? MealType.suggested()
        mode = .foods
        caloriesText = ""
        proteinText = ""
        carbsText = ""
        fatText = ""
    }

    /// Edição de uma refeição existente (no modo em que ela foi registrada).
    init(editing meal: Meal) {
        self.day = meal.day
        self.editing = meal
        name = meal.name
        type = meal.type
        mode = meal.items.isEmpty ? .manual : .foods
        items = meal.items.map(ItemDraft.init)
        caloriesText = NumberParser.format(meal.calories)
        proteinText = NumberParser.format(meal.protein)
        carbsText = NumberParser.format(meal.carbs)
        fatText = NumberParser.format(meal.fat)
        portionBase = meal.macros
        showsPortion = true
    }

    /// Nova refeição já preenchida a partir de outra, com uma porção (atalho "editar antes de adicionar").
    convenience init(day: Date, template: Meal, portion: Portion = .one) {
        self.init(day: day)
        fill(from: template)
        apply(portion)
    }

    var isEditing: Bool { editing != nil }

    // MARK: - Repetir refeição

    /// Preenche o formulário com os dados de uma refeição anterior (o dia continua sendo o selecionado).
    func fill(from template: Meal) {
        name = template.name
        type = template.type
        let templateItems = template.items
        mode = templateItems.isEmpty ? .manual : .foods
        items = templateItems.map { item in
            var copy = item
            copy.id = UUID()
            return ItemDraft(item: copy)
        }
        caloriesText = NumberParser.format(template.calories)
        proteinText = NumberParser.format(template.protein)
        carbsText = NumberParser.format(template.carbs)
        fatText = NumberParser.format(template.fat)
        portionBase = template.macros
        portion = .one
        showsPortion = true
    }

    // MARK: - Alimentos

    func add(_ food: Food, grams: Double = MealFormViewModel.defaultGrams) {
        items.append(ItemDraft(item: MealItem(food: food, grams: grams)))
    }

    /// Resultado de `addFromText`.
    struct TextOutcome: Equatable {
        var added = 0
        /// Alimentos sem quantidade no texto que receberam os gramas sugeridos.
        var suggested = 0
        /// Trechos que não casaram com nenhum alimento.
        var notFound: [String] = []
    }

    /// Adiciona os alimentos de um texto escrito ou ditado ("200g de arroz e 150g de carne").
    /// Quantidades ditas no texto ficam travadas. Os alimentos sem quantidade recebem os gramas que cabem
    /// no `budget`, sem mexer nos que já estavam na refeição (sem orçamento, entram com 100 g).
    @discardableResult
    func addFromText(_ text: String, custom: [Food] = [], budget: Macros? = nil) -> TextOutcome {
        var outcome = TextOutcome()
        var unquantified: Set<ItemDraft.ID> = []
        for entry in MealTextParser.parse(text, custom: custom) {
            guard let food = entry.food else {
                outcome.notFound.append(entry.query)
                continue
            }
            add(food, grams: entry.grams ?? Self.defaultGrams)
            outcome.added += 1
            if entry.grams == nil {
                unquantified.insert(items[items.count - 1].id)
            } else {
                items[items.count - 1].isLocked = true
            }
        }
        if let budget, !unquantified.isEmpty {
            let fixed = items.map { unquantified.contains($0.id) ? nil : ($0.grams ?? 0) }
            applySuggestion(budget: budget, fixed: fixed)
            outcome.suggested = unquantified.count
        }
        return outcome
    }

    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func remove(_ id: ItemDraft.ID) {
        items.removeAll { $0.id == id }
    }

    /// Soma (ou subtrai) gramas de um item, sem passar dos limites (1 a 2000 g).
    func adjustGrams(of id: ItemDraft.ID, by delta: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let current = items[index].grams ?? 0
        let range = NumericField.grams.range
        let newValue = min(max(current + delta, range.lowerBound), range.upperBound)
        items[index].gramsText = NumberParser.format(newValue)
        items[index].baseGrams = newValue
        portion = .one
    }

    /// Define os gramas de um item (ex.: sugestão "quanto posso comer").
    func setGrams(_ grams: Double, for id: ItemDraft.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].gramsText = NumberParser.format(grams)
        items[index].baseGrams = grams
        portion = .one
    }

    /// "Quanto posso comer?": troca os gramas dos alimentos pela sugestão que cabe no orçamento.
    /// Os travados ficam como estão e contam no orçamento.
    func suggestPortions(budget: Macros) {
        applySuggestion(budget: budget, fixed: items.map { $0.isLocked ? ($0.grams ?? 0) : nil })
    }

    /// Ajusta um alimento (±), trava a quantidade dele e recalcula os outros para continuar cabendo.
    func adjustAndRebalance(_ id: ItemDraft.ID, by delta: Double, budget: Macros) {
        adjustGrams(of: id, by: delta)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isLocked = true
        suggestPortions(budget: budget)
    }

    /// Trava ou destrava a quantidade de um alimento.
    func toggleLock(_ id: ItemDraft.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isLocked.toggle()
    }

    private func applySuggestion(budget: Macros, fixed: [Double?]) {
        let grams = MealPlanner.suggestGrams(
            for: items.map(\.item.per100g),
            budget: budget,
            fixed: fixed,
            units: items.map(\.item.unit)
        )
        for (index, value) in grams.enumerated() where items.indices.contains(index) && fixed[index] == nil {
            items[index].gramsText = NumberParser.format(value)
            items[index].baseGrams = value
        }
        portion = .one
    }

    /// Soma dos alimentos, ou `nil` se não houver alimentos ou algum tiver gramas inválidos.
    var itemsTotal: Macros? {
        guard !items.isEmpty else { return nil }
        var total = Macros.zero
        for draft in items {
            guard let macros = draft.macros else { return nil }
            total = total + macros
        }
        return total
    }

    /// Nome automático a partir dos alimentos: "Arroz + Patinho + Feijão".
    var autoName: String {
        var seen = Set<String>()
        let names = items.map(\.item.shortName).filter { seen.insert($0).inserted }
        let joined = names.joined(separator: " + ")
        return joined.count > Self.maxNameLength ? String(joined.prefix(Self.maxNameLength - 1)) + "…" : joined
    }

    // MARK: - Porção

    /// Multiplica a refeição: no modo por alimentos, os gramas; no digitado, calorias e macros.
    func apply(_ newPortion: Portion) {
        portion = newPortion
        switch mode {
        case .foods:
            for index in items.indices {
                let grams = (items[index].baseGrams * newPortion.rawValue).rounded()
                items[index].gramsText = NumberParser.format(max(grams, 1))
            }
        case .manual:
            guard let base = portionBase else { return }
            let scaled = base.scaled(by: newPortion.rawValue)
            caloriesText = NumberParser.format(scaled.calories)
            proteinText = NumberParser.format(scaled.protein)
            carbsText = NumberParser.format(scaled.carbs)
            fatText = NumberParser.format(scaled.fat)
        }
    }

    // MARK: - Validação

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nome que será salvo: o digitado ou, por alimentos, o automático.
    var effectiveName: String {
        if trimmedName.isEmpty && mode == .foods { return autoName }
        return trimmedName
    }

    var nameError: String? {
        if effectiveName.isEmpty { return "Dê um nome à refeição." }
        if trimmedName.count > Self.maxNameLength { return "Use no máximo \(Self.maxNameLength) caracteres." }
        return nil
    }

    /// Problema na lista de alimentos (modo por alimentos).
    var itemsError: String? {
        guard mode == .foods else { return nil }
        if items.isEmpty { return "Adicione pelo menos um alimento." }
        if items.contains(where: { $0.grams == nil }) { return "Confira os gramas: entre 1 e 2000 g por alimento." }
        return nil
    }

    /// Valores digitados à mão, ou `nil` se algum campo estiver vazio ou fora da faixa.
    var manualMacros: Macros? {
        guard let calories = NumericField.calories.value(from: caloriesText),
              let protein = NumericField.protein.value(from: proteinText),
              let carbs = NumericField.carbs.value(from: carbsText),
              let fat = NumericField.fat.value(from: fatText) else { return nil }
        return Macros(calories: calories, protein: protein, carbs: carbs, fat: fat)
    }

    /// Totais da refeição no modo atual.
    var macros: Macros? {
        mode == .foods ? itemsTotal : manualMacros
    }

    var isValid: Bool { nameError == nil && itemsError == nil && macros != nil }

    /// Calorias estimadas pelos macros (P×4 + C×4 + G×9), quando os três estão preenchidos.
    /// Ajuda a conferir o rótulo do alimento ou a preencher as calorias.
    var caloriesFromMacros: Double? {
        guard let protein = NumericField.protein.value(from: proteinText),
              let carbs = NumericField.carbs.value(from: carbsText),
              let fat = NumericField.fat.value(from: fatText) else { return nil }
        return protein * NutritionCalculator.kcalPerGramProtein
            + carbs * NutritionCalculator.kcalPerGramCarb
            + fat * NutritionCalculator.kcalPerGramFat
    }

    /// `true` se as calorias digitadas diferem bastante (>15% e >20 kcal) do que os macros indicam.
    var caloriesLookInconsistent: Bool {
        guard let estimated = caloriesFromMacros,
              let typed = NumericField.calories.value(from: caloriesText) else { return false }
        let difference = abs(typed - estimated)
        return difference > 20 && difference > estimated * 0.15
    }

    func useCaloriesFromMacros() {
        guard let estimated = caloriesFromMacros else { return }
        caloriesText = NumberParser.format(estimated.rounded())
    }

    // MARK: - Persistência

    /// Itens finais (com os gramas digitados).
    private var finalItems: [MealItem] {
        items.compactMap { draft in
            guard let grams = draft.grams else { return nil }
            var item = draft.item
            item.grams = grams
            return item
        }
    }

    /// Cria ou atualiza a refeição. Retorna `false` se o formulário for inválido.
    @discardableResult
    func save(in context: ModelContext) -> Bool {
        guard isValid, let macros else { return false }

        switch (mode, editing) {
        case (.foods, let meal?):
            meal.name = effectiveName
            meal.type = type
            meal.setItems(finalItems)
        case (.foods, nil):
            context.insert(Meal(name: effectiveName, type: type, day: day, items: finalItems))
        case (.manual, let meal?):
            meal.name = effectiveName
            meal.type = type
            meal.items = []
            meal.calories = macros.calories
            meal.protein = macros.protein
            meal.carbs = macros.carbs
            meal.fat = macros.fat
        case (.manual, nil):
            context.insert(Meal(
                name: effectiveName,
                type: type,
                day: day,
                calories: macros.calories,
                protein: macros.protein,
                carbs: macros.carbs,
                fat: macros.fat
            ))
        }
        try? context.save()
        return true
    }
}
