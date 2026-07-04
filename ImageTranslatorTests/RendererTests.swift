import XCTest
@testable import ImageTranslator
import CoreGraphics

final class RendererTests: XCTestCase {

    func testRendererDefaultInit() {
        let renderer = TranslationRenderer()
        XCTAssertNotNil(renderer)
    }

    func testRendererCustomConfigInit() {
        let config = RendererConfig(
            overlayColor: .red,
            textColor: .blue,
            fontSizeRatio: 0.5,
            padding: 4.0
        )
        let renderer = TranslationRenderer(config: config)
        XCTAssertNotNil(renderer)
    }

    func testRendererCustomColorInit() {
        let renderer = TranslationRenderer(
            overlayColor: .green,
            textColor: .yellow,
            fontSizeRatio: 0.8,
            padding: 1.0
        )
        XCTAssertNotNil(renderer)
    }

    func testRendererWithEmptyBlocks() {
        let renderer = TranslationRenderer()
        let image = createTestImage(width: 100, height: 100)
        let result = renderer.render(originalImage: image, textBlocks: [], translations: [])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, 100)
        XCTAssertEqual(result?.height, 100)
    }

    func testRendererWithSingleBlock() {
        let renderer = TranslationRenderer()
        let image = createTestImage(width: 200, height: 100)
        let block = TextBlock(text: "Hello", rect: CGRect(x: 10, y: 10, width: 80, height: 30), confidence: 1.0)
        let result = renderer.render(originalImage: image, textBlocks: [block], translations: ["Hola"])
        XCTAssertNotNil(result)
    }

    func testRendererWithMultipleBlocks() {
        let renderer = TranslationRenderer()
        let image = createTestImage(width: 400, height: 200)
        let blocks = [
            TextBlock(text: "A", rect: CGRect(x: 10, y: 10, width: 80, height: 30), confidence: 1.0),
            TextBlock(text: "B", rect: CGRect(x: 10, y: 60, width: 80, height: 30), confidence: 0.9),
        ]
        let result = renderer.render(originalImage: image, textBlocks: blocks, translations: ["A", "B"])
        XCTAssertNotNil(result)
    }

    func testRendererCustomColors() {
        let renderer = TranslationRenderer(
            overlayColor: .red,
            textColor: .white,
            fontSizeRatio: 0.6,
            padding: 3.0
        )
        let image = createTestImage(width: 200, height: 100)
        let block = TextBlock(text: "Test", rect: CGRect(x: 10, y: 10, width: 80, height: 40), confidence: 1.0)
        let result = renderer.render(originalImage: image, textBlocks: [block], translations: ["Prueba"])
        XCTAssertNotNil(result)
    }

    func testRendererDoesNotModifyOriginal() {
        let renderer = TranslationRenderer()
        let original = createTestImage(width: 100, height: 100)
        let block = TextBlock(text: "X", rect: CGRect(x: 0, y: 0, width: 50, height: 20), confidence: 1.0)
        _ = renderer.render(originalImage: original, textBlocks: [block], translations: ["Y"])
        XCTAssertEqual(original.width, 100)
        XCTAssertEqual(original.height, 100)
    }

    func testRendererWithLongText() {
        let renderer = TranslationRenderer()
        let image = createTestImage(width: 200, height: 100)
        let block = TextBlock(text: "Long", rect: CGRect(x: 10, y: 10, width: 60, height: 30), confidence: 1.0)
        let result = renderer.render(originalImage: image, textBlocks: [block], translations: ["A very long translation that might wrap"])
        XCTAssertNotNil(result)
    }

    private func createTestImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(gray: 0.5, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
