import Cocoa
import SwiftUI

enum CaptureError: Error {
    case permissionDenied
    case captureFailed
    case invalidRegion
}

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()

    private var overlayWindow: NSWindow?
    private var captureCompletion: ((Result<CGImage, CaptureError>) -> Void)?
    private init() {}

    func startCapture(completion: @escaping (Result<CGImage, CaptureError>) -> Void) {
        checkPermission { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    completion(.failure(.permissionDenied))
                }
                return
            }

            DispatchQueue.main.async {
                self?.showOverlay(completion: completion)
            }
        }
    }

    private func checkPermission(completion: @escaping (Bool) -> Void) {
        if CGPreflightScreenCaptureAccess() {
            completion(true)
        } else {
            CGRequestScreenCaptureAccess()
            completion(false)
        }
    }

    private func showOverlay(completion: @escaping (Result<CGImage, CaptureError>) -> Void) {
        captureCompletion = completion

        let overlayView = CaptureOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.captureRegion(rect)
            },
            onCancel: { [weak self] in
                self?.cleanup()
                self?.captureCompletion?(.failure(.invalidRegion))
            }
        )

        let hostingController = NSHostingController(rootView: overlayView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let window = NSWindow(
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
        print("[DEBUG] captureRegion rect (points): \(rect)")
        
        // Retina: CGDisplayCreateImage 返回像素，rect 是点坐标，需要乘以 scale
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        print("[DEBUG] scaled rect (pixels): \(scaledRect), scale: \(scale)")
        
        let midPoint = CGPoint(x: rect.midX, y: rect.midY)
        let targetDisplay = displayContainingPoint(midPoint)

        guard let image = CGDisplayCreateImage(targetDisplay) else {
            cleanup()
            captureCompletion?(.failure(.captureFailed))
            return
        }
        
        print("[DEBUG] full image: \(image.width)x\(image.height)")

        let croppedImage = image.cropping(to: scaledRect)
        cleanup()

        guard let cropped = croppedImage else {
            captureCompletion?(.failure(.captureFailed))
            return
        }

        print("[DEBUG] cropped: \(cropped.width)x\(cropped.height)")
        captureCompletion?(.success(cropped))
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
