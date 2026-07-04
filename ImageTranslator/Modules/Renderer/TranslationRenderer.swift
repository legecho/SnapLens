import Foundation
import CoreGraphics
import AppKit

struct RendererConfig {
    var overlayColor: NSColor
    var textColor: NSColor
    var fontSizeRatio: CGFloat
    var padding: CGFloat

    static let `default` = RendererConfig(
        overlayColor: .white,
        textColor: .black,
        fontSizeRatio: 0.75,
        padding: 2.0
    )
}

final class TranslationRenderer {
    private let config: RendererConfig

    init(config: RendererConfig = .default) {
        self.config = config
    }

    init(overlayColor: NSColor = .white, textColor: NSColor = .black, fontSizeRatio: CGFloat = 0.75, padding: CGFloat = 2.0) {
        self.config = RendererConfig(
            overlayColor: overlayColor,
            textColor: textColor,
            fontSizeRatio: fontSizeRatio,
            padding: padding
        )
    }

    func render(originalImage: CGImage, textBlocks: [TextBlock], translations: [String]) -> CGImage? {
        let width = originalImage.width
        let height = originalImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(originalImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for (block, translation) in zip(textBlocks, translations) {
            let paddedRect = block.rect.insetBy(dx: -config.padding, dy: -config.padding)
            drawOverlay(in: context, rect: paddedRect)
            drawText(in: context, text: translation, rect: paddedRect)
        }

        return context.makeImage()
    }

    private func drawOverlay(in context: CGContext, rect: CGRect) {
        let color = config.overlayColor.cgColor
        context.setFillColor(color)
        context.fill(rect)
    }

    private func drawText(in context: CGContext, text: String, rect: CGRect) {
        let baseFontSize = rect.height * config.fontSizeRatio
        let maxLineWidth = rect.width - config.padding * 2

        let lines = wrapText(text, into: maxLineWidth, baseFontSize: baseFontSize, rect: rect)
        let totalHeight = lines.reduce(0) { $0 + $1.size.height }
        var currentY = rect.minY + (rect.height - totalHeight) / 2

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        for line in lines {
            let attributedString = NSAttributedString(
                string: line.text,
                attributes: [
                    .font: NSFont.systemFont(ofSize: line.fontSize),
                    .foregroundColor: config.textColor,
                    .paragraphStyle: paragraphStyle
                ]
            )

            let textSize = attributedString.size()
            let drawRect = CGRect(
                x: rect.minX + config.padding + (maxLineWidth - textSize.width) / 2,
                y: currentY + (line.size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            context.saveGState()
            context.translateBy(x: 0, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            attributedString.draw(with: drawRect, options: [], context: nil)
            context.restoreGState()

            currentY += line.size.height
        }
    }

    private func wrapText(_ text: String, into maxWidth: CGFloat, baseFontSize: CGFloat, rect: CGRect) -> [(text: String, fontSize: CGFloat, size: CGSize)] {
        var result: [(text: String, fontSize: CGFloat, size: CGSize)] = []
        let remainingWidth = maxWidth

        let candidateLines = text.components(separatedBy: .newlines)

        var fontSize = baseFontSize

        for candidate in candidateLines {
            let trimmed = candidate.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(("", fontSize, CGSize(width: 0, height: fontSize * 1.2)))
                continue
            }

            let fittedLines = fitText(trimmed, intoWidth: remainingWidth, startingFontSize: fontSize)
            fontSize = fittedLines.first?.fontSize ?? fontSize

            for fitted in fittedLines {
                result.append(fitted)
            }
        }

        return result
    }

    private func fitText(_ text: String, intoWidth maxWidth: CGFloat, startingFontSize: CGFloat) -> [(text: String, fontSize: CGFloat, size: CGSize)] {
        var fontSize = startingFontSize
        var result: [(text: String, fontSize: CGFloat, size: CGSize)] = []

        let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        var currentLine = ""

        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let testSize = measureText(testLine, fontSize: fontSize)

            if testSize.width > maxWidth && !currentLine.isEmpty {
                let finalSize = measureText(currentLine, fontSize: fontSize)
                result.append((currentLine, fontSize, finalSize))
                currentLine = word
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            while true {
                let finalSize = measureText(currentLine, fontSize: fontSize)
                if finalSize.width <= maxWidth || fontSize <= 4 {
                    result.append((currentLine, fontSize, finalSize))
                    break
                }
                fontSize -= 1
            }
        }

        return result
    }

    private func measureText(_ text: String, fontSize: CGFloat) -> CGSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize)
        ]
        return (text as NSString).size(withAttributes: attributes)
    }
}
