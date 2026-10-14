import Foundation

/// Campos numéricos do app, cada um com sua faixa de valores aceitos.
/// Centralizar aqui garante que onboarding, perfil e refeições usem as mesmas regras.
enum NumericField {
    case age
    case weight
    case height
    case calories
    case protein
    case carbs
    case fat
    /// Quantidade de um alimento na refeição.
    case grams

    var label: String {
        switch self {
        case .age: "Idade"
        case .weight: "Peso"
        case .height: "Altura"
        case .calories: "Calorias"
        case .protein: "Proteína"
        case .carbs: "Carboidrato"
        case .fat: "Gordura"
        case .grams: "Quantidade"
        }
    }

    var unit: String {
        switch self {
        case .age: "anos"
        case .weight: "kg"
        case .height: "cm"
        case .calories: "kcal"
        case .protein, .carbs, .fat, .grams: "g"
        }
    }

    /// Faixa aceita. Fora disso consideramos erro de digitação ou valor absurdo.
    var range: ClosedRange<Double> {
        switch self {
        case .age: 14...100
        case .weight: 30...300
        case .height: 120...230
        case .calories: 0...5000
        case .protein, .carbs, .fat: 0...500
        case .grams: 1...2000
        }
    }

    /// Idade é sempre inteira; os demais aceitam decimal (ex.: 72,5 kg).
    var allowsDecimal: Bool { self != .age }

    // MARK: - Validação

    /// Converte o texto digitado em número, ou `nil` se estiver vazio, mal formatado ou fora da faixa.
    func value(from text: String) -> Double? {
        guard let number = NumberParser.parse(text, allowsDecimal: allowsDecimal),
              range.contains(number) else { return nil }
        return number
    }

    /// Mensagem de erro para mostrar abaixo do campo, ou `nil` se o valor for válido.
    func errorMessage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return "Informe \(label.lowercased())."
        }
        guard let number = NumberParser.parse(trimmed, allowsDecimal: allowsDecimal) else {
            return allowsDecimal ? "Digite apenas números." : "Digite um número inteiro."
        }
        guard range.contains(number) else {
            let min = NumberParser.format(range.lowerBound)
            let max = NumberParser.format(range.upperBound)
            return "\(label) deve estar entre \(min) e \(max) \(unit)."
        }
        return nil
    }
}

/// Conversão entre texto e número aceitando vírgula ou ponto como separador decimal.
enum NumberParser {

    /// Aceita "72", "72,5" ou "72.5". Rejeita letras, sinais, notação científica e mais de um separador.
    static func parse(_ text: String, allowsDecimal: Bool = true) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let separators = normalized.filter { $0 == "." }.count
        let onlyValidChars = normalized.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") }

        guard onlyValidChars,
              separators <= (allowsDecimal ? 1 : 0),
              normalized != "." else { return nil }

        return Double(normalized)
    }

    /// Formata para exibir/editar: sem casas decimais quando inteiro, até 1 casa caso contrário.
    /// Usa o separador decimal do idioma do aparelho (vírgula em pt-BR).
    static func format(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0...1))
                .grouping(.never)
                .locale(locale)
        )
    }
}
