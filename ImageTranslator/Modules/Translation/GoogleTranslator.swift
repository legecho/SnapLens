import Foundation

final class GoogleTranslator: TranslationProvider {
    let name = "Google"
    private let apiKey: String
    private let baseURL = "https://translation.googleapis.com/language/translate/v2"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranslationError.apiKeyMissing
        }

        guard let url = URL(string: baseURL) else {
            throw TranslationError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let encodedSource = sourceLang.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? sourceLang
        let encodedTarget = targetLang.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetLang
        let body = "key=\(apiKey)&q=\(encodedText)&source=\(encodedSource)&target=\(encodedTarget)&format=text"
        request.httpBody = body.data(using: .utf8)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw TranslationError.rateLimitExceeded
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let translations = dataDict["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw TranslationError.invalidResponse
        }

        return translatedText
    }

    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        guard !apiKey.isEmpty else {
            throw TranslationError.apiKeyMissing
        }

        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "source", value: sourceLang),
            URLQueryItem(name: "target", value: targetLang),
            URLQueryItem(name: "format", value: "text")
        ]

        guard let url = urlComponents.url else {
            throw TranslationError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "q": texts
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw TranslationError.rateLimitExceeded
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TranslationError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataDict = json["data"] as? [String: Any],
              let translations = dataDict["translations"] as? [[String: Any]] else {
            throw TranslationError.invalidResponse
        }

        return translations.compactMap { $0["translatedText"] as? String }
    }
}
