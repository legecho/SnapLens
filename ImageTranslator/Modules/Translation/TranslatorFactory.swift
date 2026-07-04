import Foundation

enum TranslationEngine: String, CaseIterable {
    case apple = "Apple (内置)"
    case google = "Google"
    case mock = "Mock (测试)"
    case deepl = "DeepL"
    case localAI = "Local AI"
}

@available(macOS 26.0, *)
class TranslatorFactory {
    static func create(engine: TranslationEngine, apiKey: String?) throws -> TranslationProvider {
        switch engine {
        case .apple:
            return AppleTranslator()
        case .google:
            return GoogleTranslator(apiKey: apiKey ?? "")
        case .mock:
            return MockTranslator()
        case .deepl:
            throw TranslationError.engineNotAvailable("DeepL not yet implemented")
        case .localAI:
            throw TranslationError.engineNotAvailable("Local AI not yet implemented")
        }
    }
}
