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
            return "需要屏幕录制权限。请打开系统设置 > 隐私与安全性 > 屏幕录制，开启 ImageTranslator，然后重启 App 再试。"
        case .captureFailed:
            return "Failed to capture screen. Please try again."
        case .invalidRegion:
            return "Invalid region selected. Please try again."
        }
    }
}

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    private var overlayWindow: OverlayWindow?
    private var captureCompletion: ((Result<CGImage, CaptureError>) -> Void)?
    private init() {}

    func startCapture(completion: @escaping (Result<CGImage, CaptureError>) -> Void) {
        print("[DEBUG] startCapture called")
        DispatchQueue.main.async {
            print("[DEBUG] showing overlay")
            self.showOverlay(completion: completion)
        }
    }

    private func showOverlay(completion: @escaping (Result<CGImage, CaptureError>) -> Void) {
        captureCompletion = completion

        let overlayView = CaptureOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.captureRegion(rect)
            },
            onCancel: { [weak self] in
                let completion = self?.captureCompletion
                self?.cleanup()
                completion?(.failure(.invalidRegion))
            }
        )

        let hostingController = NSHostingController(rootView: overlayView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = OverlayWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.contentView = hostingController.view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.makeKeyAndOrderFront(nil)

        overlayWindow = window
    }

    private func captureRegion(_ rect: CGRect) {
        print("[DEBUG] captureRegion called with rect: \(rect)")
        
        // Save completion and close overlay
        let completion = captureCompletion
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
        
        // Wait for overlay to fully disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Capture full screen first for debugging
            guard let fullImage = CGDisplayCreateImage(CGMainDisplayID()) else {
                print("[DEBUG] CGDisplayCreateImage failed")
                completion?(.failure(.captureFailed))
                return
            }
            
            // Save full screen for debugging
            let debugURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("debug_fullscreen_\(Int(Date().timeIntervalSince1970)).png")
            if let nsImage = NSImage(cgImage: fullImage, size: NSSize(width: fullImage.width, height: fullImage.height)),
               let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: debugURL)
                print("[DEBUG] Full screen saved to: \(debugURL.path)")
            }
            
            print("[DEBUG] full screen: \(fullImage.width)x\(fullImage.height)")
            
            let screenFrame = NSScreen.main!.frame
            print("[DEBUG] screen frame: \(screenFrame)")
            
            let scaleX = CGFloat(fullImage.width) / screenFrame.width
            let scaleY = CGFloat(fullImage.height) / screenFrame.height
            print("[DEBUG] scale: \(scaleX)x\(scaleY)")
            
            // Convert SwiftUI rect to CG coordinates
            let cropRect = CGRect(
                x: rect.origin.x * scaleX,
                y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            print("[DEBUG] cropRect: \(cropRect)")
            
            guard let cropped = fullImage.cropping(to: cropRect) else {
                print("[DEBUG] crop failed")
                completion?(.failure(.captureFailed))
                return
            }
            
            print("[DEBUG] capture success: \(cropped.width)x\(cropped.height)")
            completion?(.success(cropped))
        }
    }

    private func cleanup() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
    }
}
