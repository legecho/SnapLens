import Cocoa
import ScreenCaptureKit
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
    private var capturedRegion: CGRect?

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
        let hasPermission = CGPreflightScreenCaptureAccess()
        completion(hasPermission)
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
        window.level = .statusBar + 1
        window.contentView = hostingController.view
        window.isOpaque = false
        window.backgroundColor = .clear
        window.makeKeyAndOrderFront(nil)

        overlayWindow = window
    }

    private func captureRegion(_ rect: CGRect) {
        let displayID = CGMainDisplayID()

        guard let image = CGDisplayCreateImage(displayID) else {
            cleanup()
            captureCompletion?(.failure(.captureFailed))
            return
        }

        let croppedImage = image.cropping(to: rect)
        cleanup()

        guard let cropped = croppedImage else {
            captureCompletion?(.failure(.captureFailed))
            return
        }

        captureCompletion?(.success(cropped))
    }

    private func cleanup() {
        DispatchQueue.main.async {
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
            self.captureCompletion = nil
            self.capturedRegion = nil
        }
    }
}
