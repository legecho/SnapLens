import Foundation
import Translation

@available(macOS 26.0, *)
final class AppleTranslator: TranslationProvider {
    let name = "Apple"

    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let config = TranslationSession.Configuration(
            source: Locale.Language(identifier: sourceLang),
            target: Locale.Language(identifier: targetLang)
        )
        let session = TranslationSession(configuration: config)
        let response = try await session.translate(text)
        return response.targetText
    }
}
