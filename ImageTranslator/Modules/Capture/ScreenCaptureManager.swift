import Cocoa
import SwiftUI

enum CaptureError: Error, LocalizedError {
    case captureFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "截图失败"
        case .permissionDenied:
            return "需要屏幕录制权限"
        }
    }
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private init() {}

    func captureFullScreen() -> CGImage? {
        // 方法1: ScreenCaptureKit (macOS 13+)
        if #available(macOS 13.0, *) {
            // ScreenCaptureKit 需要异步调用，这里同步方法暂时跳过
        }

        // 方法2: CGDisplayCreateImage
        if let image = CGDisplayCreateImage(CGMainDisplayID()) {
            print("[DEBUG] CGDisplayCreateImage: \(image.width)x\(image.height)")
            return image
        }

        print("[DEBUG] All capture methods failed")
        return nil
    }

    func cropImage(_ image: CGImage, rect: CGRect) -> CGImage? {
        // rect 已经是图片像素坐标，直接裁剪
        print("[DEBUG] cropImage: \(rect)")
        return image.cropping(to: rect)
    }

    func saveDebugImage(_ image: CGImage, prefix: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(prefix)_\(Int(Date().timeIntervalSince1970)).png")
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
            print("[DEBUG] Saved \(prefix) to: \(url.path)")
        }
    }
}
