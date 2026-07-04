import XCTest
@testable import ImageTranslator

final class TranslationTests: XCTestCase {

    func testTranslatorFactoryCreatesGoogleTranslator() {
        let translator = TranslatorFactory.create(engine: .google, apiKey: "test-key")
        XCTAssertTrue(translator is GoogleTranslator)
        XCTAssertEqual(translator.name, "Google")
    }

    func testGoogleTranslatorInitialization() {
        let translator = GoogleTranslator(apiKey: "test-key")
        XCTAssertNotNil(translator)
        XCTAssertEqual(translator.name, "Google")
    }

    func testTranslationErrorCases() {
        let errors: [TranslationError] = [.invalidResponse, .rateLimitExceeded, .networkError, .apiKeyMissing]
        XCTAssertEqual(errors.count, 4)
    }

    func testTranslationEngineCases() {
        let engines = TranslationEngine.allCases
        XCTAssertEqual(engines.count, 3)
        XCTAssertEqual(engines[0], .google)
        XCTAssertEqual(engines[1], .deepl)
        XCTAssertEqual(engines[2], .localAI)
    }

    func testGoogleTranslatorWithEmptyApiKeyThrows() async {
        let translator = GoogleTranslator(apiKey: "")
        do {
            _ = try await translator.translate("Hello", from: "en", to: "zh")
            XCTFail("Should throw apiKeyMissing error")
        } catch {
            XCTAssertTrue(error is TranslationError)
        }
    }
}
