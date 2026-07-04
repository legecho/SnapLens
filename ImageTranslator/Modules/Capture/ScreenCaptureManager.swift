import Cocoa
import SwiftUI

enum CaptureError: Error, LocalizedError {
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "截图失败，请检查屏幕录制权限"
        }
    }
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private init() {}
    
    func captureFullScreen() -> CGImage? {
        // 方法1: 尝试 CGWindowListCreateImage 捕获所有窗口
        if let image = CGWindowListCreateImage(
            .null,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .nominalResolution, .bestResolution]
        ) {
            print("[DEBUG] CGWindowListCreateImage success: \(image.width)x\(image.height)")
            return image
        }
        
        // 方法2: 回退到 CGDisplayCreateImage
        if let image = CGDisplayCreateImage(CGMainDisplayID()) {
            print("[DEBUG] CGDisplayCreateImage success: \(image.width)x\(image.height)")
            return image
        }
        
        print("[DEBUG] All capture methods failed")
        return nil
    }
    
    func cropImage(_ image: CGImage, rect: CGRect) -> CGImage? {
        let screenFrame = NSScreen.main!.frame
        let scaleX = CGFloat(image.width) / screenFrame.width
        let scaleY = CGFloat(image.height) / screenFrame.height
        
        let cropRect = CGRect(
            x: rect.origin.x * scaleX,
            y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        print("[DEBUG] cropImage: input rect=\(rect), cropRect=\(cropRect)")
        
        return image.cropping(to: cropRect)
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
