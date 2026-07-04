import SwiftUI
import AppKit

struct MenuBarView: View {
    @State private var isTranslating = false
    @State private var lastError: String?
    @State private var translatedImage: NSImage?

    private let screenCaptureManager = ScreenCaptureManager.shared
    private let ocrProvider = VisionOCR()
    private let renderer = TranslationRenderer()
    private let configManager = ConfigManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ImageTranslator")
                .font(.headline)

            Divider()

            if let image = translatedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 150)
                    .cornerRadius(4)

                HStack {
                    Button(action: saveImage) {
                        Label("Save Image", systemImage: "square.and.arrow.down")
                    }

                    Button(action: clearImage) {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: startTranslation) {
                    Label("Start Translation", systemImage: "text.viewfinder")
                }
                .disabled(isTranslating)
            }

            if isTranslating {
                ProgressView("Processing...")
                    .progressViewStyle(.linear)
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
        .frame(width: 300, height: translatedImage != nil ? 300 : 200)
        .onReceive(NotificationCenter.default.publisher(for: HotKeyManager.hotKeyTriggeredNotification)) { _ in
            startTranslation()
        }
    }

    private func startTranslation() {
        isTranslating = true
        lastError = nil
        translatedImage = nil

        screenCaptureManager.startCapture { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let cgImage):
                Task {
                    await self.processImage(cgImage)
                }
            case .failure(let error):
                await MainActor.run {
                    self.isTranslating = false
                    switch error {
                    case .permissionDenied:
                        self.lastError = "Screen capture permission denied. Please grant permission in System Settings."
                    case .captureFailed:
                        self.lastError = "Failed to capture screen."
                    case .invalidRegion:
                        self.lastError = "Invalid region selected."
                    }
                }
            }
        }
    }

    private func processImage(_ image: CGImage) async {
        do {
            let textBlocks = try await ocrProvider.recognize(image: image)
            let texts = textBlocks.map { $0.text }
            let translations = try await configManager.getTranslator().translateBatch(
                texts,
                from: "auto",
                to: configManager.targetLanguage
            )

            if let rendered = renderer.render(originalImage: image, textBlocks: textBlocks, translations: translations) {
                await MainActor.run {
                    self.translatedImage = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
                    self.isTranslating = false
                }
            } else {
                await MainActor.run {
                    self.isTranslating = false
                    self.lastError = "Failed to render translation."
                }
            }
        } catch {
            await MainActor.run {
                self.isTranslating = false
                if let ocrError = error as? OCRError {
                    switch ocrError {
                    case .noTextFound:
                        self.lastError = "No text found in the selected region."
                    case .recognitionFailed:
                        self.lastError = "Text recognition failed."
                    case .invalidImage:
                        self.lastError = "Invalid image for OCR."
                    }
                } else {
                    self.lastError = "Translation failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func saveImage() {
        guard let image = translatedImage else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "translated_\(Int(Date().timeIntervalSince1970)).png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    return
                }
                do {
                    try pngData.write(to: url)
                } catch {
                    lastError = "Failed to save image: \(error.localizedDescription)"
                }
            }
        }
    }

    private func clearImage() {
        translatedImage = nil
    }

    private func openSettings() {
        NSApp.delegate.flatMap { $0 as? AppDelegate }?.openSettings()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MenuBarView()
}
