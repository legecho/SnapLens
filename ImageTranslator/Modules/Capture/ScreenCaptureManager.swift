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
        
        // Save completion before cleanup
        let completion = captureCompletion
        
        // Close overlay first so it doesn't appear in screenshot
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
        
        // Small delay to ensure overlay is gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Capture full screen
            guard let displayID = CGMainDisplayID().description.isEmpty ? nil : CGMainDisplayID(),
                  let fullImage = CGDisplayCreateImage(displayID) else {
                print("[DEBUG] failed to capture display")
                completion?(.failure(.captureFailed))
                return
            }
            
            print("[DEBUG] full screen captured: \(fullImage.width)x\(fullImage.height)")
            
            // Convert rect from SwiftUI (top-left origin) to CG (bottom-left origin)
            let screenHeight = CGFloat(fullImage.height)
            let cropRect = CGRect(
                x: rect.origin.x * 2,  // Retina 2x
                y: screenHeight - (rect.origin.y + rect.height) * 2,
                width: rect.width * 2,
                height: rect.height * 2
            )
            print("[DEBUG] cropRect: \(cropRect)")
            
            // Crop the image
            guard let croppedImage = fullImage.cropping(to: cropRect) else {
                print("[DEBUG] failed to crop")
                completion?(.failure(.captureFailed))
                return
            }
            
            print("[DEBUG] capture success, size: \(croppedImage.width)x\(croppedImage.height)")
            completion?(.success(croppedImage))
        }
    }

    private func displayContainingPoint(_ point: CGPoint) -> CGDirectDisplayID {
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, &activeDisplays, &displayCount)

        for i in 0..<Int(displayCount) {
            let bounds = CGDisplayBounds(activeDisplays[i])
            if bounds.contains(point) { return activeDisplays[i] }
        }
        return CGMainDisplayID()
    }

    private func cleanup() {
        DispatchQueue.main.async {
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
            self.captureCompletion = nil
        }
    }
}
