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
            return "Failed to capture screen."
        case .invalidRegion:
            return "Invalid region selected."
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
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.makeKeyAndOrderFront(nil)

        overlayWindow = window
    }

    private func captureRegion(_ rect: CGRect) {
        print("[DEBUG] captureRegion called with rect: \(rect)")
        
        let completion = captureCompletion
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
        
        // 先截全屏，再裁剪指定区域
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let fullImage = CGDisplayCreateImage(CGMainDisplayID()) else {
                print("[DEBUG] CGDisplayCreateImage failed")
                completion?(.failure(.captureFailed))
                return
            }
            
            let screenFrame = NSScreen.main!.frame
            let scaleX = CGFloat(fullImage.width) / screenFrame.width
            let scaleY = CGFloat(fullImage.height) / screenFrame.height
            
            // SwiftUI 坐标 → CG 坐标
            let cropRect = CGRect(
                x: rect.origin.x * scaleX,
                y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )
            print("[DEBUG] fullImage: \(fullImage.width)x\(fullImage.height), screenFrame: \(screenFrame), cropRect: \(cropRect)")
            
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
