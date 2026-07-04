import Foundation
import CoreGraphics

struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let rect: CGRect
    let confidence: Float
}

enum OCRError: Error {
    case recognitionFailed
    case noTextFound
    case invalidImage
}

protocol OCRProvider {
    func recognize(image: CGImage) async throws -> [TextBlock]
}
