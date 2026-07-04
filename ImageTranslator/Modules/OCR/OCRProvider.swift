import Foundation
import CoreGraphics

struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let rect: CGRect
    let confidence: Float
}

enum OCRError: Error, LocalizedError {
    case recognitionFailed
    case noTextFound
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .recognitionFailed:
            return "Text recognition failed. Please try again."
        case .noTextFound:
            return "No text found in the selected region."
        case .invalidImage:
            return "Invalid image for OCR."
        }
    }
}

protocol OCRProvider {
    func recognize(image: CGImage) async throws -> [TextBlock]
}
