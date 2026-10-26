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

    /// Peso com até 2 casas, para ritmos semanais: "0,73 kg" (o `kgText` usa 1 casa).
    var preciseKgText: String {
        formatted(.number.precision(.fractionLength(0...2))) + " kg"
    }

    /// Peso com sinal e até 2 casas: "−0,45 kg", "+0,1 kg".
    var signedPreciseKgText: String {
        formatted(.number.precision(.fractionLength(0...2)).sign(strategy: .always(includingZero: false))) + " kg"
    }

    /// Calorias com sinal sempre visível: "+276" ou "−414".
    var signedKcalText: String {
        let rounded = self.rounded()
        if rounded == 0 { return "0" }
        return rounded.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always()))
    }
}
