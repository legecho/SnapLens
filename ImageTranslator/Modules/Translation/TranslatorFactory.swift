import Foundation

enum TranslationEngine: String, CaseIterable {
    case google = "Google"
    case deepl = "DeepL"
    case localAI = "Local AI"
}

class TranslatorFactory {
    static func create(engine: TranslationEngine, apiKey: String?) -> TranslationProvider {
        switch engine {
        case .google:
            return GoogleTranslator(apiKey: apiKey ?? "")
        case .deepl:
            fatalError("DeepL not yet implemented")
        case .localAI:
            fatalError("Local AI not yet implemented")
        }
    }
}
