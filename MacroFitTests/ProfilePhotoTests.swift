import SwiftData
import UIKit
import XCTest
@testable import MacroFit

/// Foto do perfil: recorte quadrado, redução, ícone da aba e gravação no SwiftData.
final class ProfilePhotoTests: XCTestCase {

    /// Imagem `width` × `height` px: metade esquerda vermelha, metade direita azul.
    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            UIColor.blue.setFill()
            context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        }
    }

    private func pixelSize(_ data: Data?) throws -> CGSize {
        let image = try XCTUnwrap(data.flatMap(UIImage.init(data:)))
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    func testLargePhotoIsCroppedToSquareAndReduced() throws {
        // 2000 × 1000 → recorta 1000 × 1000 no centro → reduz para 600 × 600
        let data = image(width: 2000, height: 1000).pngData()!
        XCTAssertEqual(try pixelSize(ProfilePhoto.prepare(data)), CGSize(width: 600, height: 600))
    }

    func testSmallPhotoIsNotEnlarged() throws {
        // 300 × 500 → quadrado de 300 (não amplia para 600)
        let data = image(width: 300, height: 500).pngData()!
        XCTAssertEqual(try pixelSize(ProfilePhoto.prepare(data)), CGSize(width: 300, height: 300))
    }

    func testCropKeepsTheCenter() throws {
        // Num retrato largo, o centro do quadrado é a divisa vermelho/azul: esquerda vermelha, direita azul
        let square = ProfilePhoto.square(image(width: 1000, height: 400), side: 400)
        let cgImage = try XCTUnwrap(square.cgImage)
        let pixels = try XCTUnwrap(cgImage.dataProvider?.data as Data?)
        let bytesPerRow = cgImage.bytesPerRow, bytesPerPixel = cgImage.bitsPerPixel / 8
        func isRed(x: Int) -> Bool {
            let offset = 200 * bytesPerRow + x * bytesPerPixel
            // BGRA (little-endian) ou RGBA: o vermelho é o canal mais forte num dos extremos
            let first = pixels[offset], third = pixels[offset + 2]
            return cgImage.bitmapInfo.contains(.byteOrder32Little) ? third > first : first > third
        }
        XCTAssertTrue(isRed(x: 50))
        XCTAssertFalse(isRed(x: 350))
    }

    func testNotAnImage() {
        XCTAssertNil(ProfilePhoto.prepare(Data("não é imagem".utf8)))
        XCTAssertNil(ProfilePhoto.tabIcon(from: Data()))
    }

    func testTabIconKeepsColors() throws {
        let data = try XCTUnwrap(ProfilePhoto.prepare(image(width: 800, height: 800).pngData()!))
        let icon = try XCTUnwrap(ProfilePhoto.tabIcon(from: data))
        XCTAssertEqual(icon.size, CGSize(width: 28, height: 28))
        XCTAssertEqual(icon.renderingMode, .alwaysOriginal, "Senão a barra de abas pinta a foto de uma cor só")
    }

    @MainActor
    func testPhotoIsSavedOnProfile() throws {
        let container = try ModelContainer(for: Schema(MacroFitSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let profile = UserProfile(sex: .male, age: 18, weightKg: 97, heightCm: 175, activity: .moderate)
        container.mainContext.insert(profile)
        XCTAssertNil(profile.photoData, "Perfil novo começa sem foto")

        profile.photoData = ProfilePhoto.prepare(image(width: 900, height: 1200).pngData()!)
        try container.mainContext.save()
        let fetched = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(try pixelSize(fetched.photoData), CGSize(width: 600, height: 600))
    }
}
