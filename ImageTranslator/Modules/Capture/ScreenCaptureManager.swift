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
        let midPoint = CGPoint(x: rect.midX, y: rect.midY)
        let targetDisplay = displayContainingPoint(midPoint)
        print("[DEBUG] target display: \(targetDisplay)")

        guard let image = CGDisplayCreateImage(targetDisplay) else {
            print("[DEBUG] failed to create display image")
            let completion = captureCompletion
            cleanup()
            completion?(.failure(.captureFailed))
            return
        }

        // Get display bounds to calculate correct crop coordinates
        let displayBounds = CGDisplayBounds(targetDisplay)
        print("[DEBUG] display bounds: \(displayBounds)")
        
        // Convert screen coordinates to display coordinates
        // The overlay window covers the full screen, but display might have different origin
        let displayFrame = NSScreen.screens.first(where: { 
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == targetDisplay 
        })?.frame ?? NSScreen.main!.frame
        print("[DEBUG] display frame: \(displayFrame)")
        
        // Scale factor between points and pixels
        let scaleX = CGFloat(image.width) / displayFrame.width
        let scaleY = CGFloat(image.height) / displayFrame.height
        
        // Convert rect from screen coordinates to display pixel coordinates
        let cropRect = CGRect(
            x: (rect.origin.x - displayFrame.origin.x) * scaleX,
            y: (displayFrame.height - rect.origin.y + displayFrame.origin.y - rect.height) * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        print("[DEBUG] cropRect: \(cropRect)")

        let croppedImage = image.cropping(to: cropRect)
        let completion = captureCompletion
        cleanup()

        guard let cropped = croppedImage else {
            print("[DEBUG] failed to crop image")
            completion?(.failure(.captureFailed))
            return
        }

        print("[DEBUG] capture success, size: \(cropped.width)x\(cropped.height)")
        completion?(.success(cropped))
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
