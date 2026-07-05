import SwiftUI

private extension NSColor {
    func savedString() -> String? {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false) else {
            return nil
        }
        return data.base64EncodedString()
    }

    static func fromSavedString(_ str: String) -> NSColor? {
        guard let data = Data(base64Encoded: str),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return color
    }
}

final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let translationEngine = "translationEngine"
        static let overlayColor = "overlayColor"
        static let autoTranslate = "autoTranslate"
        static let googleAPIKey = "googleAPIKey"
    }

    @Published var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }

    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }

    @Published var translationEngine: TranslationEngine {
        didSet { defaults.set(translationEngine.rawValue, forKey: Keys.translationEngine) }
    }

    @Published var overlayColor: NSColor {
        didSet { defaults.set(overlayColor.savedString(), forKey: Keys.overlayColor) }
    }

    @Published var autoTranslate: Bool {
        didSet { defaults.set(autoTranslate, forKey: Keys.autoTranslate) }
    }

    @Published var googleAPIKey: String? {
        didSet { defaults.set(googleAPIKey, forKey: Keys.googleAPIKey) }
    }

    private init() {
        let savedEngine = defaults.string(forKey: Keys.translationEngine)
        self.translationEngine = savedEngine.flatMap { TranslationEngine(rawValue: $0) } ?? .apple
        self.sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "en"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "zh-CN"
        self.autoTranslate = defaults.object(forKey: Keys.autoTranslate) as? Bool ?? true
        self.googleAPIKey = defaults.string(forKey: Keys.googleAPIKey)

        if let savedColor = defaults.string(forKey: Keys.overlayColor) {
            self.overlayColor = NSColor.fromSavedString(savedColor) ?? .white
        } else {
            self.overlayColor = .white
        }
    }

    func getTranslator() -> TranslationProvider {
        do {
            return try TranslatorFactory.create(engine: translationEngine, apiKey: googleAPIKey)
        } catch {
            print("[DEBUG] TranslatorFactory error: \(error), falling back to MockTranslator")
            return MockTranslator()
        }
    }
}
