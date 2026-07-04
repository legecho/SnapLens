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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Method 1: Try CGDisplayCreateImage
            if let displayImage = CGDisplayCreateImage(CGMainDisplayID()) {
                print("[DEBUG] CGDisplayCreateImage success: \(displayImage.width)x\(displayImage.height)")
                
                let screenFrame = NSScreen.main!.frame
                let scaleX = CGFloat(displayImage.width) / screenFrame.width
                let scaleY = CGFloat(displayImage.height) / screenFrame.height
                
                // Convert SwiftUI rect to CG coordinates
                let cropRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                print("[DEBUG] cropRect: \(cropRect)")
                
                if let cropped = displayImage.cropping(to: cropRect) {
                    print("[DEBUG] crop success: \(cropped.width)x\(cropped.height)")
                    completion?(.success(cropped))
                    return
                }
            }
            
            // Method 2: Try NSScreen bitmap
            print("[DEBUG] Trying NSScreen bitmap capture")
            if let screen = NSScreen.main,
               let bitmap = screen.bitmapImageRep(forCachingDisplay(in: screen.frame)) {
                screen.cacheDisplay(in: screen.frame, to: bitmap)
                
                let cgImage = bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil)
                if let cgImage = cgImage {
                    print("[DEBUG] NSScreen bitmap success: \(cgImage.width)x\(cgImage.height)")
                    
                    let screenFrame = screen.frame
                    let scaleX = CGFloat(cgImage.width) / screenFrame.width
                    let scaleY = CGFloat(cgImage.height) / screenFrame.height
                    
                    let cropRect = CGRect(
                        x: rect.origin.x * scaleX,
                        y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
                        width: rect.width * scaleX,
                        height: rect.height * scaleY
                    )
                    
                    if let cropped = cgImage.cropping(to: cropRect) {
                        print("[DEBUG] NSScreen crop success: \(cropped.width)x\(cropped.height)")
                        completion?(.success(cropped))
                        return
                    }
                }
            }
            
            print("[DEBUG] All capture methods failed")
            completion?(.failure(.captureFailed))
        }
    }

    private func cleanup() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
    }
}
