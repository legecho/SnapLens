import Foundation
import Translation

final class AppleTranslator: TranslationProvider {
    let name = "Apple"

    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        if #available(macOS 26.0, *) {
            return try await translateNew(text, from: sourceLang, to: targetLang)
        } else if #available(macOS 13.0, *) {
            return try await translateOld(text, from: sourceLang, to: targetLang)
        } else {
            throw TranslationError.engineNotAvailable("Apple Translation requires macOS 13+")
        }
    }

    @available(macOS 26.0, *)
    private func translateNew(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let source = Locale.Language(identifier: mapLanguageCode(sourceLang))
        let target = Locale.Language(identifier: mapLanguageCode(targetLang))
        let session = TranslationSession(installedSource: source, target: target)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.translate(text)
            task.result { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.targetString)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }

    @available(macOS 13.0, *)
    private func translateOld(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let source = Locale.Language(identifier: mapLanguageCode(sourceLang))
        let target = Locale.Language(identifier: mapLanguageCode(targetLang))
        let session = TranslationSession()

        return try await withCheckedThrowingContinuation { continuation in
            let request = TranslationSession.Translatable(text)
            session.translate(request, sourceLanguage: source, targetLanguage: target) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.targetString)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let translated = try await translate(text, from: sourceLang, to targetLang)
            results.append(translated)
        }
        return results
    }

    private func mapLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-CN", "zh-Hans": return "zh-Hans"
        case "zh-TW", "zh-Hant": return "zh-Hant"
        case "en": return "en"
        case "ja": return "ja"
        case "ko": return "ko"
        case "auto": return "en"
        default: return code
        }
    }
}
