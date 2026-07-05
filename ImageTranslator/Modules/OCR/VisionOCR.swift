import Foundation
import Vision
import CoreGraphics
import AppKit

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
        
        // Save image for debugging
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ocr_debug_\(Int(Date().timeIntervalSince1970)).png")
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: tempURL)
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
        request.usesLanguageCorrection = true

        // Convert to proper format for Vision
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed
        }

        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        

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

            
            let block = TextBlock(
                text: candidate.string,
                rect: rect,
                confidence: candidate.confidence
            )
            textBlocks.append(block)
        }

        if textBlocks.isEmpty {
            throw OCRError.noTextFound
        }

        return textBlocks
    }
}
