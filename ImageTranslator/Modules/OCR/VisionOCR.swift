import Foundation
import Vision
import CoreGraphics

final class VisionOCR: OCRProvider {
    private let recognitionLanguages: [String]
    private let recognitionLevel: VNRequestTextRecognitionLevel

    init(
        recognitionLanguages: [String] = ["en-US", "zh-Hans", "zh-Hant"],
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.recognitionLevel = recognitionLevel
    }

    func recognize(image: CGImage) async throws -> [TextBlock] {
        print("[DEBUG] OCR input: \(image.width)x\(image.height)")
        
        let request = VNRecognizeTextRequest { _, _ in }
        request.recognitionLevel = recognitionLevel
        request.recognitionLanguages = recognitionLanguages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("[DEBUG] OCR perform error: \(error)")
            throw OCRError.recognitionFailed
        }

        guard let observations = request.results else {
            print("[DEBUG] OCR no results")
            throw OCRError.noTextFound
        }
        
        print("[DEBUG] OCR found \(observations.count) observations")

        let imageHeight = CGFloat(image.height)
        let imageWidth = CGFloat(image.width)

        var textBlocks: [TextBlock] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let boundingBox = observation.boundingBox
            let rect = CGRect(
                x: boundingBox.origin.x * imageWidth,
                y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
                width: boundingBox.width * imageWidth,
                height: boundingBox.height * imageHeight
            )

            print("[DEBUG] OCR text: '\(candidate.string)' confidence: \(candidate.confidence)")
            
            let block = TextBlock(
                text: candidate.string,
                rect: rect,
                confidence: candidate.confidence
            )
            textBlocks.append(block)
        }

        if textBlocks.isEmpty {
            print("[DEBUG] OCR no text blocks after filtering")
            throw OCRError.noTextFound
        }

        return textBlocks
    }
}
