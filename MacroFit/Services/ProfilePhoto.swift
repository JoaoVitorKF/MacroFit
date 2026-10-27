import UIKit

/// Foto do perfil: prepara a imagem escolhida na galeria e gera o ícone redondo da aba Perfil.
enum ProfilePhoto {
    /// Lado da foto salva, em pixels. Basta para o avatar e deixa o arquivo pequeno (~50–100 KB).
    static let side: CGFloat = 600
    /// Tamanho do ícone na barra de abas, em pontos (o mesmo dos símbolos do sistema).
    static let tabIconSize: CGFloat = 28

    /// Recorta o centro em quadrado, reduz para no máximo `side` px e devolve em JPEG.
    /// `nil` se os dados não forem uma imagem.
    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return square(image, side: side).jpegData(compressionQuality: 0.85)
    }

    /// Ícone redondo para a aba Perfil, com as cores da foto (`alwaysOriginal`; senão o iOS pinta de uma cor só).
    static func tabIcon(from data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        let size = CGSize(width: tabIconSize, height: tabIconSize)
        let icon = UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            square(image, side: tabIconSize * 3).draw(in: CGRect(origin: .zero, size: size))
        }
        return icon.withRenderingMode(.alwaysOriginal)
    }

    /// Centro da imagem em quadrado, com no máximo `side` px de lado (nunca amplia).
    static func square(_ image: UIImage, side: CGFloat) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let crop = min(pixelSize.width, pixelSize.height)
        let output = min(crop, side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: output, height: output), format: format).image { _ in
            // Desenha a imagem inteira deslocada, para o centro cair no quadrado
            let scale = output / crop
            let drawSize = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
            image.draw(in: CGRect(
                x: (output - drawSize.width) / 2,
                y: (output - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
    }
}
