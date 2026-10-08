import XCTest
@testable import MacroFit

/// Testes da leitura e validação dos campos numéricos.
final class ValidationTests: XCTestCase {

    func testParseAcceptsCommaAndDot() {
        XCTAssertEqual(NumberParser.parse("72"), 72)
        XCTAssertEqual(NumberParser.parse("72,5"), 72.5)
        XCTAssertEqual(NumberParser.parse("72.5"), 72.5)
        XCTAssertEqual(NumberParser.parse(" 80 "), 80)
    }

    func testParseRejectsInvalidText() {
        XCTAssertNil(NumberParser.parse(""))
        XCTAssertNil(NumberParser.parse("   "))
        XCTAssertNil(NumberParser.parse("abc"))
        XCTAssertNil(NumberParser.parse("-5"))
        XCTAssertNil(NumberParser.parse("1e5"))
        XCTAssertNil(NumberParser.parse("7,2,5"))
        XCTAssertNil(NumberParser.parse(","))
    }

    func testIntegerOnlyField() {
        XCTAssertEqual(NumericField.age.value(from: "30"), 30)
        XCTAssertNil(NumericField.age.value(from: "30,5"))
    }

    func testRanges() {
        XCTAssertNil(NumericField.age.value(from: "13"))
        XCTAssertEqual(NumericField.age.value(from: "14"), 14)
        XCTAssertNil(NumericField.weight.value(from: "500"))
        XCTAssertEqual(NumericField.weight.value(from: "300"), 300)
        XCTAssertNil(NumericField.height.value(from: "80"))
        XCTAssertEqual(NumericField.calories.value(from: "0"), 0)
        XCTAssertNil(NumericField.calories.value(from: "5001"))
        XCTAssertNil(NumericField.protein.value(from: "501"))
    }

    func testErrorMessages() {
        XCTAssertNil(NumericField.weight.errorMessage(for: "80"))
        XCTAssertNotNil(NumericField.weight.errorMessage(for: ""))
        XCTAssertNotNil(NumericField.weight.errorMessage(for: "abc"))
        XCTAssertNotNil(NumericField.weight.errorMessage(for: "10"))
    }

    func testFormat() {
        let ptBR = Locale(identifier: "pt_BR")
        XCTAssertEqual(NumberParser.format(80, locale: ptBR), "80")
        XCTAssertEqual(NumberParser.format(72.5, locale: ptBR), "72,5")
        XCTAssertEqual(NumberParser.format(1500, locale: ptBR), "1500")
    }
}
