import CoreGraphics
import AppKit

extension CGImage {
    var size: CGSize {
        CGSize(width: width, height: height)
    }

    func toNSImage() -> NSImage {
        NSImage(cgImage: self, size: size)
    }
}

extension NSImage {
    func toCGImage() -> CGImage? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
