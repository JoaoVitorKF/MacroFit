import Foundation

/// Alimentos que se comem por unidade (ovo, pão francês, banana…): quanto pesa uma unidade e como chamá-la.
/// Serve para a sugestão de gramas não propor "85 g de ovo" e para mostrar "≈ 2 ovos" ao lado dos gramas.
/// Os pesos são os mesmos aproximados que o `MealTextParser` usa para "2 ovos".
struct FoodUnit: Equatable {
    let grams: Double
    let singular: String
    let plural: String
    /// Máximo de unidades numa sugestão: ninguém come 5 pães no jantar só porque cabe nas calorias.
    var maxCount: Double = 3

    /// "2 ovos", "1 pão", "1,5 fatia". Arredonda para meia unidade; `nil` se der menos de meia.
    func describe(grams total: Double) -> String? {
        let count = (total / grams * 2).rounded() / 2
        guard count >= 0.5 else { return nil }
        let number = NumberParser.format(count)
        return "\(number) \(count > 1 ? plural : singular)"
    }
}

enum FoodUnits {
    /// Unidade de cada alimento da TACO que costuma ser contado (pelo número na tabela).
    static let byTacoId: [Int: FoodUnit] = {
        let egg = FoodUnit(grams: 50, singular: "ovo", plural: "ovos", maxCount: 4)
        let roll = FoodUnit(grams: 50, singular: "pão", plural: "pães")
        let slice = FoodUnit(grams: 25, singular: "fatia", plural: "fatias", maxCount: 4)
        let banana = FoodUnit(grams: 90, singular: "banana", plural: "bananas", maxCount: 2)
        let apple = FoodUnit(grams: 130, singular: "maçã", plural: "maçãs", maxCount: 2)
        let orange = FoodUnit(grams: 140, singular: "laranja", plural: "laranjas", maxCount: 2)
        let yogurt = FoodUnit(grams: 170, singular: "pote", plural: "potes", maxCount: 2)
        let burger = FoodUnit(grams: 90, singular: "hambúrguer", plural: "hambúrgueres", maxCount: 2)

        var table: [Int: FoodUnit] = [:]
        for id in [488, 489, 490] { table[id] = egg }                 // ovo de galinha inteiro
        table[53] = roll                                              // pão francês
        for id in [48, 49, 50, 51, 52] { table[id] = slice }          // pães de forma
        for id in [178, 179, 180, 182] { table[id] = banana }         // maçã, nanica, ouro, prata
        for id in [221, 222] { table[id] = apple }
        for id in [208, 210, 212, 214, 216] { table[id] = orange }    // só as cruas (não os sucos)
        for id in [448, 449, 451, 452] { table[id] = yogurt }
        for id in [415, 416, 417] { table[id] = burger }
        return table
    }()

    /// Unidade a partir do `Food.id`/`MealItem.foodId` ("taco-488"). Alimentos próprios não têm.
    static func unit(forFoodId foodId: String) -> FoodUnit? {
        guard foodId.hasPrefix("taco-"), let number = Int(foodId.dropFirst(5)) else { return nil }
        return byTacoId[number]
    }
}

extension MealItem {
    /// Unidade do alimento, se ele costuma ser contado (ovo, pão…).
    var unit: FoodUnit? { FoodUnits.unit(forFoodId: foodId) }
}
