import Foundation
import Translation

@available(macOS 13.0, *)
final class AppleTranslator: TranslationProvider {
    let name = "Apple"
    
    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let source = languageCode(for: sourceLang)
        let target = languageCode(for: targetLang)
        
        let session = LTTranslator(session: .init(source: source, target: target))
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = LTranslationRequest(source: text)
            session.translate(request) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.targetText)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let translated = try await translate(text, from: sourceLang, to: targetLang)
            results.append(translated)
        }
        return results
    }
    
    private func languageCode(for code: String) -> Language {
        switch code {
        case "zh-CN", "zh-Hans": return .init(identifier: "zh-Hans")
        case "zh-TW", "zh-Hant": return .init(identifier: "zh-Hant")
        case "en": return .init(identifier: "en")
        case "ja": return .init(identifier: "ja")
        case "ko": return .init(identifier: "ko")
        case "auto": return .init(identifier: "en")
        default: return .init(identifier: code)
        }
    }
}
