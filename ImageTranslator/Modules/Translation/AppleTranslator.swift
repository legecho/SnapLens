import Foundation
import Translation

@available(macOS 26.0, *)
final class AppleTranslator: TranslationProvider {
    let name = "Apple"

    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let sourceLanguage = mapLanguageCode(sourceLang)
        let targetLanguage = mapLanguageCode(targetLang)

        let session = TranslationSession(
            installedSource: Locale.Language(identifier: sourceLanguage),
            target: Locale.Language(identifier: targetLanguage)
        )

        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            throw TranslationError.engineNotAvailable(
                "Apple Translation failed: \(error.localizedDescription). "
                + "Please ensure language packs are installed in System Settings > General > Language & Region."
            )
        }
    }

    private func mapLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-CN": return "zh-Hans"
        case "zh-TW": return "zh-Hant"
        case "en": return "en-GB"
        case "ja": return "ja"
        case "ko": return "ko"
        case "es": return "es"
        case "fr": return "fr"
        case "de": return "de"
        case "ru": return "ru"
        case "pt": return "pt"
        default: return code
        }
    }
}
