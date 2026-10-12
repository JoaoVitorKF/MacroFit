import Foundation

/// Tabela de alimentos do app: a TACO embutida (`Resources/taco.json`, gerada por `Tools/taco/generate_taco.py`)
/// mais os alimentos próprios do usuário, com busca em português.
final class FoodDatabase {
    static let shared = FoodDatabase()

    /// Alimentos da TACO, na ordem da tabela.
    let foods: [Food]
    private let byTacoId: [Int: Food]

    /// Carrega a TACO do bundle do app.
    convenience init(bundle: Bundle = .main) {
        self.init(foods: Self.loadTaco(from: bundle))
    }

    init(foods: [Food]) {
        self.foods = foods
        self.byTacoId = Dictionary(foods.compactMap { food in food.tacoId.map { ($0, food) } }, uniquingKeysWith: { first, _ in first })
    }

    func food(tacoId: Int) -> Food? { byTacoId[tacoId] }

    /// Sugestões para quando a busca está vazia: alimentos próprios + os mais comuns no dia a dia.
    func common(custom: [Food] = []) -> [Food] {
        custom + FoodSearch.commonTacoIds.compactMap(food(tacoId:))
    }

    /// Busca por nome, sem diferenciar acentos, maiúsculas e plural.
    /// Ordem: apelidos comuns ("carne" → patinho grelhado…), alimentos próprios, depois por relevância,
    /// preferindo alimentos prontos (cozido, grelhado) aos crus.
    func search(_ query: String, custom: [Food] = [], limit: Int = 40) -> [Food] {
        let tokens = FoodSearch.queryTokens(query)
        guard !tokens.isEmpty else { return common(custom: custom) }

        let alias = FoodSearch.alias(for: tokens)
        let wantsRaw = tokens.contains { FoodSearch.rawWords.contains($0) }

        var scored: [(food: Food, score: Double)] = []
        for food in custom + foods {
            var score = FoodSearch.matchScore(queryTokens: tokens, name: food.name, wantsRaw: wantsRaw)
            // Apelido: vale se o alimento também casa com a busca toda ("arroz cru" não puxa o cozido),
            // ou se a busca é só o apelido (sinônimos como "aipim", que não aparecem no nome)
            if let alias, let id = food.tacoId, let rank = alias.tacoIds.firstIndex(of: id),
               score != nil || alias.coversWholeQuery {
                score = (score ?? 0) + 1_000 - Double(rank) * 10
            }
            guard var total = score else { continue }
            if food.isCustom { total += 5_000 } // o que o usuário cadastrou vem sempre primeiro
            scored.append((food, total))
        }

        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.food.name < $1.food.name }
            .prefix(limit)
            .map(\.food)
    }

    // MARK: - Carregamento

    private struct TacoRecord: Decodable {
        let id: Int
        let name: String
        let category: String
        let kcal: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    private static func loadTaco(from bundle: Bundle) -> [Food] {
        guard let url = bundle.url(forResource: "taco", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([TacoRecord].self, from: data) else {
            assertionFailure("taco.json não encontrado ou inválido")
            return []
        }
        return records.map { record in
            Food(
                source: .taco(record.id),
                name: record.name,
                category: record.category,
                per100g: Macros(calories: record.kcal, protein: record.protein, carbs: record.carbs, fat: record.fat)
            )
        }
    }
}

/// Regras da busca de alimentos (funções puras, testáveis).
enum FoodSearch {

    /// Palavras ignoradas na busca ("peito de frango" = "peito frango").
    static let stopwords: Set<String> = ["de", "da", "do", "das", "dos", "e", "a", "o", "um", "uma", "no", "na"]

    /// Palavras que indicam alimento cru (ficam por último, a menos que a busca peça "cru").
    static let rawWords: Set<String> = ["cru", "crua", "crus", "cruas"]

    /// Palavras que indicam alimento pronto (preferidos: é o que se pesa no prato).
    static let preparedPrefixes = ["cozid", "grelhad", "assad", "refogad"]

    /// Apelidos do dia a dia → alimentos da TACO em ordem de preferência.
    /// A chave é comparada com o começo da busca já normalizada (sem acento, sem "de", no singular).
    static let aliases: [(key: [String], tacoIds: [Int])] = [
        (["carne", "moida"], [326]),                                   // acém moído cozido
        (["carne"], [377, 346, 370, 383, 351, 326, 328, 368]),         // patinho grelhado, contra-filé…
        (["patinho"], [377]),
        (["alcatra"], [370]),
        (["picanha"], [383, 381]),
        (["contra", "file"], [346, 344]),
        (["file", "mignon"], [358]),
        (["peito", "frango"], [410, 408]),
        (["frango"], [410, 408, 403, 398, 413]),                       // peito sem pele grelhado primeiro
        (["arroz"], [3, 1, 526]),                                      // tipo 1 cozido, integral cozido, carreteiro
        (["feijao"], [561, 567, 539]),                                 // carioca cozido, preto cozido, tropeiro
        (["ovo"], [488, 490, 489]),                                    // cozido, frito, cru
        (["pao"], [53, 52, 48]),                                       // francês, forma integral, aveia
        (["batata", "doce"], [88]),
        (["batata"], [91, 88, 93]),
        (["mandioca"], [129, 132]),
        (["aipim"], [129, 132]),
        (["macaxeira"], [129, 132]),
        (["banana"], [182, 179, 178]),
        (["queijo"], [461, 463, 467]),
        (["iogurte"], [448, 449]),
        (["azeite"], [260]),
        (["peixe"], [301, 308, 293, 317]),                             // merluza assada, pescada, corvina, salmão
        (["porco"], [432, 435, 429]),
        (["mamao"], [226, 225]),
        (["maca"], [222, 221]),
    ]

    /// Alimentos mostrados com a busca vazia.
    static let commonTacoIds = [3, 561, 410, 377, 488, 53, 88, 182, 7, 129, 1, 326]

    /// Normaliza: minúsculas, sem acento, só letras e números.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
        let cleaned = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(cleaned)
    }

    static func words(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map(String.init)
    }

    /// Palavras da busca, sem stopwords.
    static func queryTokens(_ query: String) -> [String] {
        words(query).filter { !stopwords.contains($0) }
    }

    /// Singular simples para comparar apelidos ("ovos" → "ovo", "batatas" → "batata").
    static func singular(_ word: String) -> String {
        word.count > 3 && word.hasSuffix("s") ? String(word.dropLast()) : word
    }

    /// Apelido que casa com o começo da busca (o mais longo vence: "carne moida" antes de "carne").
    /// `coversWholeQuery` diz se a busca é exatamente o apelido, sem palavras a mais.
    static func alias(for queryTokens: [String]) -> (tacoIds: [Int], coversWholeQuery: Bool)? {
        let tokens = queryTokens.map(singular)
        guard let match = aliases
            .filter({ alias in alias.key.count <= tokens.count && Array(tokens.prefix(alias.key.count)) == alias.key })
            .max(by: { $0.key.count < $1.key.count }) else { return nil }
        return (match.tacoIds, match.key.count == tokens.count)
    }

    /// Pontuação de um nome para a busca, ou `nil` se alguma palavra da busca não aparece no nome.
    static func matchScore(queryTokens: [String], name: String, wantsRaw: Bool) -> Double? {
        let nameWords = words(name)
        var score = 0.0

        for token in queryTokens {
            var best = 0.0
            for word in nameWords {
                if word == token || word == singular(token) {
                    best = max(best, 3)
                } else if word.hasPrefix(token) || (word.count >= 3 && token.hasPrefix(word)) {
                    best = max(best, 2) // "feij" → "feijao"; "ovos" → "ovo"
                } else if token.count >= 4 && word.contains(token) {
                    best = max(best, 1)
                }
            }
            guard best > 0 else { return nil }
            score += best
        }

        if let first = queryTokens.first, let firstWord = nameWords.first,
           firstWord == first || firstWord.hasPrefix(first) || firstWord == singular(first) {
            score += 20 // "arroz" deve achar "Arroz, …" antes de "Feijão com arroz"
        }
        if nameWords.contains(where: { word in preparedPrefixes.contains { word.hasPrefix($0) } }) {
            score += 8
        }
        if !wantsRaw && nameWords.contains(where: rawWords.contains) {
            score -= 15
        }
        score -= Double(name.count) * 0.05 // nomes mais simples primeiro
        return score
    }
}
