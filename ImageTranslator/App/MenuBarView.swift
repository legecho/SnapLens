import SwiftUI
import AppKit

struct MenuBarView: View {
    @State private var isTranslating = false
    @State private var lastError: String?
    @State private var translatedImage: NSImage?

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
    }

    private func startTranslation() {
        NSApp.delegate.flatMap { $0 as? AppDelegate }?.startCapture()
    }

    private func saveImage() {
        guard let image = translatedImage else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "translated_\(Int(Date().timeIntervalSince1970)).png"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
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
