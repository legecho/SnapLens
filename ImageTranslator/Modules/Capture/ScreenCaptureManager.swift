import Cocoa
import SwiftUI
import ScreenCaptureKit

enum CaptureError: Error {
    case permissionDenied
    case captureFailed
    case invalidRegion
}

@available(macOS 14.0, *)
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
        Task {
            do {
                let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                completion(true)
            } catch {
                completion(false)
            }
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

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        print("[DEBUG] scaled rect (pixels): \(scaledRect), scale: \(scale)")

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    cleanup()
                    captureCompletion?(.failure(.captureFailed))
                    return
                }

                let config = SCStreamConfiguration()
                config.width = Int(display.width)
                config.height = Int(display.height)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.colorSpace = CGColorSpaceCreateDeviceRGB()

                let image = try await SCImageManager.captureImage(content: content, configuration: config)
                print("[DEBUG] captured: \(image.width)x\(image.height)")

                // 裁剪选区
                guard let cropped = image.cropping(to: scaledRect) else {
                    cleanup()
                    captureCompletion?(.failure(.captureFailed))
                    return
                }

                print("[DEBUG] cropped: \(cropped.width)x\(cropped.height)")
                cleanup()
                captureCompletion?(.success(cropped))

            } catch {
                print("[DEBUG] capture error: \(error)")
                cleanup()
                captureCompletion?(.failure(.captureFailed))
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
