import Cocoa
import SwiftUI

enum CaptureError: Error, LocalizedError {
    case noScreen
    case permissionDenied
    case captureFailed
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .noScreen:
            return "No screen available for capture."
        case .permissionDenied:
            return "需要屏幕录制权限。"
        case .captureFailed:
            return "Failed to capture screen. Please try again."
        case .invalidRegion:
            return "Invalid region selected. Please try again."
        }
    }
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    private var captureCompletion: ((Result<CGImage, CaptureError>) -> Void)?
    private init() {}

    func startCapture(completion: @escaping (Result<CGImage, CaptureError>) -> Void) {
        print("[DEBUG] startCapture called")
        captureCompletion = completion
        
        // 直接截屏，不使用覆盖层
        DispatchQueue.main.async {
            self.captureScreen()
        }
    }

    private func captureScreen() {
        print("[DEBUG] captureScreen called")
        
        // 获取所有窗口信息
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            print("[DEBUG] Failed to get window list")
            captureCompletion?(.failure(.captureFailed))
            return
        }
        
        print("[DEBUG] Found \(windowList.count) windows")
        
        // 打印所有窗口信息
        for (index, window) in windowList.enumerated() {
            let name = window[kCGWindowName as String] as? String ?? "Unknown"
            let owner = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            print("[DEBUG] Window \(index): \(owner) - \(name), layer: \(layer), bounds: \(bounds)")
        }
        
        // 尝试截取最上层窗口
        for window in windowList {
            guard let windowNumber = window[kCGWindowNumber as String] as? CGWindowID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0, // 只取普通窗口（layer 0）
                  let name = window[kCGWindowName as String] as? String,
                  !name.isEmpty else {
                continue
            }
            
            print("[DEBUG] Trying to capture window: \(name)")
            
            if let image = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowNumber,
                [.boundsIgnoreFraming, .bestResolution, .nominalResolution]
            ) {
                print("[DEBUG] Captured window '\(name)': \(image.width)x\(image.height)")
                
                // 保存截图
                let debugURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("debug_window_\(name)_\(Int(Date().timeIntervalSince1970)).png")
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: debugURL)
                    print("[DEBUG] Window screenshot saved to: \(debugURL.path)")
                }
                
                captureCompletion?(.success(image))
                return
            }
        }
        
        // 如果没有找到可截取的窗口，尝试截取整个屏幕
        print("[DEBUG] No window captured, trying full screen")
        if let image = CGDisplayCreateImage(CGMainDisplayID()) {
            print("[DEBUG] Full screen captured: \(image.width)x\(image.height)")
            captureCompletion?(.success(image))
        } else {
            captureCompletion?(.failure(.captureFailed))
        }
    }
}
