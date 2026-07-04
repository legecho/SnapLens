import Foundation

enum TranslationEngine: String, CaseIterable {
    case google = "Google"
    case deepl = "DeepL"
    case localAI = "Local AI"
}

class TranslatorFactory {
    static func create(engine: TranslationEngine, apiKey: String?) throws -> TranslationProvider {
        switch engine {
        case .google:
            return GoogleTranslator(apiKey: apiKey ?? "")
        case .deepl:
            throw TranslationError.engineNotAvailable("DeepL not yet implemented")
        case .localAI:
            throw TranslationError.engineNotAvailable("Local AI not yet implemented")
        }
    }
}
