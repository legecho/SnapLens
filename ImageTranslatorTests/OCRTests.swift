import XCTest
@testable import ImageTranslator
import CoreGraphics

final class OCRTests: XCTestCase {
    func testTextBlockCreation() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
        let block = TextBlock(text: "Hello", rect: rect, confidence: 0.95)

        XCTAssertEqual(block.text, "Hello")
        XCTAssertEqual(block.rect, rect)
        XCTAssertEqual(block.confidence, 0.95, accuracy: 0.001)
        XCTAssertNotNil(block.id)
    }

    func testTextBlockUniqueId() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 50)
        let block1 = TextBlock(text: "A", rect: rect, confidence: 1.0)
        let block2 = TextBlock(text: "A", rect: rect, confidence: 1.0)

        XCTAssertNotEqual(block1.id, block2.id)
    }

    func testVisionOCRInitialization() {
        let ocr = VisionOCR()
        XCTAssertNotNil(ocr)
    }

    func testVisionOCRWithCustomLanguages() {
        let ocr = VisionOCR(recognitionLanguages: ["en-US"])
        XCTAssertNotNil(ocr)
    }

    func testOCRErrorCases() {
        let errors: [OCRError] = [.recognitionFailed, .noTextFound, .invalidImage]
        XCTAssertEqual(errors.count, 3)
    }
}
