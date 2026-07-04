import Foundation

// 模拟翻译器：直接返回原文（不翻译），用于测试截图+OCR+渲染流程
final class AppleTranslator: TranslationProvider {
    let name = "Apple"

    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        // 暂时返回原文，后续接真实翻译API
        return text
    }
}
