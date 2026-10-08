import Foundation

// Formatação de números para exibir na tela (não para edição — para isso use `NumberParser.format`).
// Usa o idioma do aparelho: em pt-BR, "2.345" e "72,5".

extension Double {
    /// Calorias arredondadas: "2.345".
    var kcalText: String {
        formatted(.number.precision(.fractionLength(0)))
    }

    /// Gramas arredondados: "160 g".
    var gramsText: String {
        formatted(.number.precision(.fractionLength(0))) + " g"
    }

    /// Calorias com sinal sempre visível: "+276" ou "−414".
    var signedKcalText: String {
        let rounded = self.rounded()
        if rounded == 0 { return "0" }
        return rounded.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always()))
    }
}
