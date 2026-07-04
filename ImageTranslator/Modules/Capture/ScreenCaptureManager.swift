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
                // 1. 获取屏幕内容
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    cleanup()
                    captureCompletion?(.failure(.noDisplayFound))
                    return
                }

                // 2. 创建过滤器
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // 3. 配置截图参数
                let config = SCStreamConfiguration()
                config.pixelFormat = kCVPixelFormatType_32BGRA

                // 根据选区设置裁剪范围（像素坐标）
                let screenFrame = NSScreen.main?.frame ?? .zero
                let scaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)

                config.sourceRect = CGRect(
                    x: Int(rect.origin.x) * scaleFactor,
                    y: Int(rect.origin.y) * scaleFactor,
                    width: Int(rect.size.width) * scaleFactor,
                    height: Int(rect.size.height) * scaleFactor
                )
                config.width = Int(rect.size.width) * scaleFactor
                config.height = Int(rect.size.height) * scaleFactor

                print("[DEBUG] config: sourceRect=\(config.sourceRect), size=\(config.width)x\(config.height)")

                // 4. 截图
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("[DEBUG] captured: \(cgImage.width)x\(cgImage.height)")

                cleanup()
                captureCompletion?(.success(cgImage))

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
