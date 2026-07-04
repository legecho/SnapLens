import Foundation

// 模拟翻译器，用于测试完整流程（无需 API Key）
final class MockTranslator: TranslationProvider {
    let name = "Mock"
    
    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // 模拟翻译：在原文前加上 [翻译]
        return "[翻译] \(text)"
    }
    
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        return texts.map { "[翻译] \($0)" }
    }
}
