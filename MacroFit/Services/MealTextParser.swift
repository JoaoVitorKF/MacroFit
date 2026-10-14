import Foundation

/// Entende uma refeição escrita ou ditada: "200g de arroz e 150g de carne", "2 ovos e 1 pão francês",
/// "arroz, feijão e frango". Separa os alimentos, lê as quantidades e encontra cada um na tabela.
enum MealTextParser {

    /// Um pedaço do texto já interpretado.
    struct Entry: Equatable {
        /// Trecho original ("150g de carne").
        let text: String
        /// O que foi buscado na tabela ("carne").
        let query: String
        /// Gramas lidos do texto, ou `nil` se não havia quantidade.
        let grams: Double?
        /// Alimento encontrado, ou `nil` se nada casou.
        let food: Food?
    }

    // MARK: - Interpretação

    /// Interpreta o texto e encontra os alimentos na tabela (TACO + alimentos próprios).
    static func parse(_ text: String, database: FoodDatabase = .shared, custom: [Food] = []) -> [Entry] {
        var entries: [Entry] = []
        for segment in segments(of: text) {
            let (amount, rest) = extractAmount(from: segment)
            var query = cleanQuery(rest)
            guard !FoodSearch.queryTokens(query).isEmpty else { continue }

            var food = database.search(query, custom: custom, limit: 1).first
            // "arroz com feijão": se o todo não casar, tenta só a primeira parte
            if food == nil, let first = query.components(separatedBy: " com ").first, first != query {
                food = database.search(first, custom: custom, limit: 1).first
                query = first
            }

            var grams: Double?
            if let amount {
                grams = self.grams(for: amount, food: food, query: query)
            }
            entries.append(Entry(text: segment, query: query, grams: grams, food: food))
        }
        return entries
    }

    // MARK: - Quantidades

    /// Quantidade lida do texto: número e unidade ("200 g", "1,5 kg", "2" ovos, "1 colher").
    struct Amount: Equatable {
        enum Unit: Equatable {
            case grams
            case kilograms
            case spoon      // colher de sopa ≈ 15 g
            case ladle      // concha ≈ 100 g
            case slice      // fatia ≈ 25 g
            case count      // unidades ("2 ovos")
        }
        let value: Double
        let unit: Unit
    }

    /// Peso típico de uma unidade (para "2 ovos", "1 pão francês", "1 banana").
    static let unitWeights: [(word: String, grams: Double)] = [
        ("ovo", 50), ("pao", 50), ("banana", 90), ("maca", 130), ("laranja", 140),
        ("bife", 120), ("file", 120), ("coxa", 100), ("sobrecoxa", 100), ("tapioca", 70),
        ("iogurte", 170), ("bisteca", 120), ("hamburguer", 90), ("salsicha", 50),
    ]

    static func grams(for amount: Amount, food: Food?, query: String) -> Double? {
        let value: Double?
        switch amount.unit {
        case .grams: value = amount.value
        case .kilograms: value = amount.value * 1000
        case .spoon: value = amount.value * 15
        case .ladle: value = amount.value * 100
        case .slice: value = amount.value * 25
        case .count:
            // "200 arroz" (sem unidade, número grande) = gramas; "2 ovos" = unidades
            if amount.value >= 10 {
                value = amount.value
            } else {
                let words = FoodSearch.words(query).map(FoodSearch.singular)
                value = unitWeights.first { words.contains($0.word) }.map { amount.value * $0.grams }
            }
        }
        guard let value else { return nil }
        let range = NumericField.grams.range
        return min(max(value.rounded(), range.lowerBound), range.upperBound)
    }

    /// Números por extenso comuns no ditado.
    private static let numberWords: [String: Double] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "três": 3, "quatro": 4, "cinco": 5,
        "meio": 0.5, "meia": 0.5,
    ]

    /// Separa a quantidade do resto: "150g de carne" → (150 g, "de carne").
    static func extractAmount(from segment: String) -> (Amount?, String) {
        let text = segment.lowercased()
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(kg|quilos?|gramas?|grs?|g|colher(?:es)?(?:\s+de\s+sopa)?|conchas?|fatias?)?(?=\s|$|[^a-zà-ú])"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let numberRange = Range(match.range(at: 1), in: text),
           let fullRange = Range(match.range, in: text) {
            let value = Double(text[numberRange].replacingOccurrences(of: ",", with: ".")) ?? 0
            let unitText = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? ""
            var rest = text
            rest.removeSubrange(fullRange)
            return (Amount(value: value, unit: unit(from: unitText)), rest)
        }
        // Número por extenso no começo: "duas bananas", "meia tapioca"
        let words = text.split(separator: " ").map(String.init)
        if let first = words.first, let value = numberWords[first] {
            return (Amount(value: value, unit: .count), words.dropFirst().joined(separator: " "))
        }
        return (nil, text)
    }

    private static func unit(from text: String) -> Amount.Unit {
        switch text {
        case let unit where unit.hasPrefix("kg") || unit.hasPrefix("quilo"): .kilograms
        case let unit where unit.hasPrefix("colher"): .spoon
        case let unit where unit.hasPrefix("concha"): .ladle
        case let unit where unit.hasPrefix("fatia"): .slice
        case "": .count
        default: .grams
        }
    }

    // MARK: - Separação dos alimentos

    /// Quebra o texto em um pedaço por alimento: vírgulas, "e", "mais", "+", quebras de linha,
    /// e também quando aparece uma nova quantidade ("200g arroz 150g feijão").
    static func segments(of text: String) -> [String] {
        var normalized = " " + text.lowercased() + " "
        // Vírgula separa alimentos, menos quando é decimal ("1,5 kg", "150,5g")
        if let comma = try? NSRegularExpression(pattern: #"(?<!\d),|,(?!\d)"#) {
            normalized = comma.stringByReplacingMatches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized), withTemplate: "|")
        }
        for separator in [";", "\n", "+", " e ", " mais "] {
            normalized = normalized.replacingOccurrences(of: separator, with: "|")
        }
        // Nova quantidade no meio de um pedaço que já tem alimento: "200g arroz 150g feijão"
        if let regex = try? NSRegularExpression(pattern: #"(?<=[a-zà-ú])\s+(?=\d)"#) {
            normalized = regex.stringByReplacingMatches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized), withTemplate: "|")
        }
        return normalized
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Limpa o nome do alimento: tira "de" do começo e pontuação ("de carne." → "carne").
    static func cleanQuery(_ text: String) -> String {
        var words = text
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .split(separator: " ")
            .map(String.init)
        while let first = words.first, ["de", "do", "da", "dos", "das"].contains(first) {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }
}
