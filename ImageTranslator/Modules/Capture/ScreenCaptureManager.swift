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
        
        let completion = captureCompletion
        
        // Close overlay
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let screenFrame = NSScreen.main!.frame
            
            // Convert SwiftUI rect (top-left origin) to CG rect (bottom-left origin)
            let cgRect = CGRect(
                x: rect.origin.x,
                y: screenFrame.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            print("[DEBUG] cgRect: \(cgRect)")
            
            // Get list of on-screen windows
            let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
            print("[DEBUG] Found \(windowList.count) on-screen windows")
            
            // Find windows that intersect with our selection rect
            var bestImage: CGImage?
            
            for windowInfo in windowList {
                guard let windowID = windowInfo[kCGWindowOwnerPID as String] as? CGWindowID,
                      let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                      let windowName = windowInfo[kCGWindowName as String] as? String else {
                    continue
                }
                
                let windowBounds = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: boundsDict["Width"] ?? 0,
                    height: boundsDict["Height"] ?? 0
                )
                
                // Check if this window intersects with our selection
                if windowBounds.intersects(cgRect) {
                    print("[DEBUG] Window '\(windowName)' intersects with selection")
                    
                    // Try to capture this specific window
                    if let windowImage = CGWindowListCreateImage(
                        .null,
                        .optionIncludingWindow,
                        windowID,
                        [.boundsIgnoreFraming, .bestResolution]
                    ) {
                        print("[DEBUG] Captured window '\(windowName)': \(windowImage.width)x\(windowImage.height)")
                        bestImage = windowImage
                        break
                    }
                }
            }
            
            // If no specific window captured, try capturing the region from all on-screen content
            if bestImage == nil {
                print("[DEBUG] No window captured, trying region capture")
                bestImage = CGWindowListCreateImage(
                    cgRect,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    [.boundsIgnoreFraming, .bestResolution]
                )
            }
            
            guard let finalImage = bestImage else {
                print("[DEBUG] All capture methods failed")
                completion?(.failure(.captureFailed))
                return
            }
            
            print("[DEBUG] Final capture: \(finalImage.width)x\(finalImage.height)")
            
            // If we captured a full window, crop to selection
            if finalImage.width > Int(cgRect.width * 2) || finalImage.height > Int(cgRect.height * 2) {
                let screenFrame = NSScreen.main!.frame
                let scaleX = CGFloat(finalImage.width) / screenFrame.width
                let scaleY = CGFloat(finalImage.height) / screenFrame.height
                
                let cropRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: (screenFrame.height - rect.origin.y - rect.height) * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                
                if let cropped = finalImage.cropping(to: cropRect) {
                    print("[DEBUG] Cropped to: \(cropped.width)x\(cropped.height)")
                    completion?(.success(cropped))
                    return
                }
            }
            
            completion?(.success(finalImage))
        }
    }

    private func cleanup() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        captureCompletion = nil
    }
}
