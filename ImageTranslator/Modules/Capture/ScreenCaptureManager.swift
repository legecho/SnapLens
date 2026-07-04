import Cocoa
import SwiftUI
import ScreenCaptureKit

enum CaptureError: Error {
    case permissionDenied
    case captureFailed
    case invalidRegion
    case noDisplayFound
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

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    cleanup()
                    captureCompletion?(.failure(.noDisplayFound))
                    return
                }

                // 截全屏，不做 sourceRect
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.pixelFormat = kCVPixelFormatType_32BGRA

                let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("[DEBUG] full screen: \(fullImage.width)x\(fullImage.height)")
                
                // 保存全屏截图用于调试
                let debugURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("debug_fullscreen_\(Int(Date().timeIntervalSince1970)).png")
                let nsImage = NSImage(cgImage: fullImage, size: NSSize(width: fullImage.width, height: fullImage.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: debugURL)
                    print("[DEBUG] Full screen saved to: \(debugURL.path)")
                }

                // 手动裁剪选区
                // 使用实际显示尺寸计算缩放比例
                let displayWidth = CGFloat(display.width)
                let displayHeight = CGFloat(display.height)
                let screenFrame = NSScreen.main?.frame ?? .zero
                let scaleX = displayWidth / screenFrame.width
                let scaleY = displayHeight / screenFrame.height
                
                let cropRect = CGRect(
                    x: rect.origin.x * scaleX,
                    y: rect.origin.y * scaleY,
                    width: rect.width * scaleX,
                    height: rect.height * scaleY
                )
                print("[DEBUG] screenFrame: \(screenFrame), displaySize: \(displayWidth)x\(displayHeight), scale: \(scaleX)x\(scaleY)")
                print("[DEBUG] cropRect: \(cropRect)")

                guard let cropped = fullImage.cropping(to: cropRect) else {
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
