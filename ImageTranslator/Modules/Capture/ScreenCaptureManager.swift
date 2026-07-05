import Cocoa
import SwiftUI
import ScreenCaptureKit

enum CaptureError: Error {
    case permissionDenied
    case captureFailed
    case invalidRegion
    case noDisplayFound
}

struct CaptureResult {
    let image: CGImage
    let screenRect: CGRect
}

@available(macOS 14.0, *)
final class ScreenCaptureManager: @unchecked Sendable {
    static let shared = ScreenCaptureManager()

    private var overlayWindow: NSWindow?
    private var captureCompletion: ((Result<CaptureResult, CaptureError>) -> Void)?
    private init() {}

    func startCapture(completion: @escaping (Result<CaptureResult, CaptureError>) -> Void) {
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
        Task {
            do {
                let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    private func showOverlay(completion: @escaping (Result<CaptureResult, CaptureError>) -> Void) {
        captureCompletion = completion
        let screenFrame = NSScreen.main?.frame ?? .zero

        let overlayView = CaptureOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.captureRegion(rect, screenFrame: screenFrame)
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
            contentRect: screenFrame,
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

    private func captureRegion(_ rect: CGRect, screenFrame: CGRect) {
        print("[DEBUG] captureRegion rect: \(rect), screenFrame: \(screenFrame)")
        // 先隐藏覆盖层，但不清除 captureCompletion
        DispatchQueue.main.async {
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
        }

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    captureCompletion?(.failure(.noDisplayFound))
                    return
                }

                // display.width/height 是逻辑点数，需要乘以 scale 得到原生像素
                let nativeW = display.width
                let nativeH = display.height
                let scale = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
                let pixelW = nativeW * scale
                let pixelH = nativeH * scale
                print("[DEBUG] display logical: \(nativeW)x\(nativeH), scale: \(scale), pixel: \(pixelW)x\(pixelH)")

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = pixelW
                config.height = pixelH
                config.pixelFormat = kCVPixelFormatType_32BGRA

                let fullImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )
                print("[DEBUG] captured: \(fullImage.width)x\(fullImage.height)")

                // 用原生像素尺寸做缩放，确保 scaleX == scaleY
                let scaleX = CGFloat(fullImage.width) / screenFrame.width
                let scaleY = CGFloat(fullImage.height) / screenFrame.height
                print("[DEBUG] scale: \(scaleX)x\(scaleY)")

                let cropRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: rect.origin.y * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                print("[DEBUG] cropRect: \(cropRect)")

                guard let cropped = fullImage.cropping(to: cropRect) else {
                    captureCompletion?(.failure(.captureFailed))
                    return
                }

                print("[DEBUG] cropped: \(cropped.width)x\(cropped.height)")
                let captureResult = CaptureResult(image: cropped, screenRect: rect)
                captureCompletion?(.success(captureResult))
                captureCompletion = nil

            } catch {
                print("[DEBUG] capture error: \(error)")
                captureCompletion?(.failure(.captureFailed))
                captureCompletion = nil
            }
        }
    }

    private func cleanup() {
        DispatchQueue.main.async {
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
            self.captureCompletion = nil
        }
    }
}
