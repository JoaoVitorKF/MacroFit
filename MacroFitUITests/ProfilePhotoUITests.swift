import XCTest

/// Foto do perfil (modo demo com `-demo-photo`: uma foto de exemplo "JV").
/// A galeria do `PhotosPicker` roda fora do app e não é testada aqui; a preparação da imagem está em `ProfilePhotoTests`.
final class ProfilePhotoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-skip-splash", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-demo", "-demo-photo", "-demo-tab", "2"]
        app.launch()
    }

    func testRemovePhoto() {
        let photo = app.buttons["foto-perfil"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertEqual(photo.label, "Trocar foto")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "perfil-com-foto"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["remover-foto"].tap()
        XCTAssertTrue(app.staticTexts["Adicionar foto"].waitForExistence(timeout: 3))
        XCTAssertEqual(photo.label, "Adicionar foto")
        XCTAssertFalse(app.buttons["remover-foto"].exists, "Sem foto, não há o que remover")
    }
}
