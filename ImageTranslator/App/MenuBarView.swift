import SwiftUI
import AppKit

struct MenuBarView: View {
    @State private var isCapturing = false
    @State private var lastError: String?
    @State private var hasCapture = false

    private let screenCaptureManager = ScreenCaptureManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ImageTranslator")
                .font(.headline)

            Divider()

            Button(action: startCapture) {
                Label("Screenshot", systemImage: "camera.viewfinder")
            }
            .disabled(isCapturing)

            if hasCapture {
                Text("Screenshot captured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }

            Button(action: quitApp) {
                Label("Quit", systemImage: "power")
            }

            if let error = lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 300, height: 180)
        .onReceive(NotificationCenter.default.publisher(for: .menuBarStartTranslation)) { _ in
            startCapture()
        }
    }

    private func startCapture() {
        isCapturing = true
        lastError = nil
        hasCapture = false

        screenCaptureManager.startCapture { result in
            switch result {
            case .success(let captureResult):
                let cgImage = captureResult.image
                let logicalSize = NSSize(width: captureResult.screenRect.width, height: captureResult.screenRect.height)
                let nsImg = NSImage(cgImage: cgImage, size: logicalSize)
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.hasCapture = true
                    ResultWindowManager.shared.show(image: nsImg, near: captureResult.screenRect)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func openSettings() {
        NSApp.delegate.flatMap { $0 as? AppDelegate }?.openSettings()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
