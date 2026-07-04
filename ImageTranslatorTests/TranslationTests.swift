import XCTest
@testable import ImageTranslator

final class TranslationTests: XCTestCase {

    func testTranslatorFactoryCreatesGoogleTranslator() throws {
        let translator = try TranslatorFactory.create(engine: .google, apiKey: "test-key")
        XCTAssertTrue(translator is GoogleTranslator)
        XCTAssertEqual(translator.name, "Google")
    }

    func testTranslatorFactoryThrowsForDeepL() {
        XCTAssertThrowsError(try TranslatorFactory.create(engine: .deepl, apiKey: nil)) { error in
            guard case TranslationError.engineNotAvailable(let message) = error else {
                XCTFail("Expected engineNotAvailable error")
                return
            }
            XCTAssertEqual(message, "DeepL not yet implemented")
        }
    }

    func testTranslatorFactoryThrowsForLocalAI() {
        XCTAssertThrowsError(try TranslatorFactory.create(engine: .localAI, apiKey: nil)) { error in
            guard case TranslationError.engineNotAvailable(let message) = error else {
                XCTFail("Expected engineNotAvailable error")
                return
            }
            XCTAssertEqual(message, "Local AI not yet implemented")
        }
    }

    func testGoogleTranslatorInitialization() {
        let translator = GoogleTranslator(apiKey: "test-key")
        XCTAssertNotNil(translator)
        XCTAssertEqual(translator.name, "Google")
    }

    func testTranslationErrorCases() {
        let errors: [TranslationError] = [.invalidResponse, .rateLimitExceeded, .networkError, .apiKeyMissing, .engineNotAvailable("test")]
        XCTAssertEqual(errors.count, 5)
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
