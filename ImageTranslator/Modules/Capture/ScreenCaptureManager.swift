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
        
        // Convert rect from SwiftUI (top-left origin) to CG (bottom-left origin)
        let screenHeight = NSScreen.main!.frame.height
        let cgRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        print("[DEBUG] cgRect: \(cgRect)")
        
        // Capture the specific region directly - overlay is semi-transparent so content shows through
        // Use a small delay to ensure the overlay has rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard let image = CGWindowListCreateImage(
                cgRect,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.boundsIgnoreFraming, .nominalResolution, .bestResolution]
            ) else {
                print("[DEBUG] CGWindowListCreateImage failed, trying fallback")
                // Fallback: capture full display and crop
                guard let fullImage = CGDisplayCreateImage(CGMainDisplayID()) else {
                    print("[DEBUG] fallback failed too")
                    let completion = self.captureCompletion
                    self.cleanup()
                    completion?(.failure(.captureFailed))
                    return
                }
                
                // Calculate crop coordinates for full display image
                let displayWidth = CGFloat(fullImage.width)
                let displayHeight = CGFloat(fullImage.height)
                let scaleX = displayWidth / NSScreen.main!.frame.width
                let scaleY = displayHeight / NSScreen.main!.frame.height
                
                let cropRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: (NSScreen.main!.frame.height - rect.origin.y - rect.height) * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                print("[DEBUG] fallback cropRect: \(cropRect)")
                
                guard let cropped = fullImage.cropping(to: cropRect) else {
                    let completion = self.captureCompletion
                    self.cleanup()
                    completion?(.failure(.captureFailed))
                    return
                }
                
                print("[DEBUG] fallback success: \(cropped.width)x\(cropped.height)")
                let completion = self.captureCompletion
                self.cleanup()
                completion?(.success(cropped))
                return
            }
            
            print("[DEBUG] capture success: \(image.width)x\(image.height)")
            let completion = self.captureCompletion
            self.cleanup()
            completion?(.success(image))
        }
    }
                // Crop the fallback image
                let cropScale = CGFloat(displayImage.width) / NSScreen.main!.frame.width
                let fallbackCrop = CGRect(
                    x: rect.origin.x * cropScale,
                    y: (screenHeight - rect.origin.y - rect.height) * cropScale,
                    width: rect.width * cropScale,
                    height: rect.height * cropScale
                )
                if let cropped = displayImage.cropping(to: fallbackCrop) {
                    print("[DEBUG] fallback capture success, size: \(cropped.width)x\(cropped.height)")
                    completion?(.success(cropped))
                } else {
                    completion?(.failure(.captureFailed))
                }
                return
            }
            
            print("[DEBUG] capture success, size: \(image.width)x\(image.height)")
            completion?(.success(image))
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
