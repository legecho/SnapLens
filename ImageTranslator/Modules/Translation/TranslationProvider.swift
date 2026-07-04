import Foundation

enum TranslationError: Error, LocalizedError {
    case invalidResponse
    case rateLimitExceeded
    case networkError
    case apiKeyMissing
    case engineNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The translation service returned an invalid response."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError:
            return "A network error occurred. Please check your connection."
        case .apiKeyMissing:
            return "API key is missing. Please configure it in Settings."
        case .engineNotAvailable(let engine):
            return "Translation engine '\(engine)' is not available."
        }
    }
}

protocol TranslationProvider {
    var name: String { get }
    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String]
}

extension TranslationProvider {
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let translated = try await translate(text, from: sourceLang, to: targetLang)
            results.append(translated)
        }
        return results
    }
}
