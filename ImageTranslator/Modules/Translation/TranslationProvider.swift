import Foundation

enum TranslationError: Error {
    case invalidResponse
    case rateLimitExceeded
    case networkError
    case apiKeyMissing
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
