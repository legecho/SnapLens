import Cocoa
import SwiftUI

final class ResultWindowManager: @unchecked Sendable {
    static let shared = ResultWindowManager()

    private var resultWindow: NSWindow?
    private var currentImage: NSImage?
    private var originalImage: NSImage?
    private var translatedImage: NSImage?

    private init() {}

    func show(image: NSImage, near screenRect: CGRect? = nil) {
        currentImage = image
        originalImage = image
        translatedImage = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let existing = self.resultWindow {
                existing.contentView = NSHostingView(rootView: ScreenshotView(
                    image: image,
                    isTranslating: true,
                    onCopy: { self.copyToClipboard() },
                    onClose: { self.close() }
                ))
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let toolBarHeight: CGFloat = 36
            let windowWidth = image.size.width
            let windowHeight = image.size.height + toolBarHeight

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: ScreenshotView(
                image: image,
                isTranslating: true,
                onCopy: { self.copyToClipboard() },
                onClose: { self.close() }
            ))
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear

            if let rect = screenRect {
                let screenFrame = NSScreen.main?.frame ?? .zero
                let windowX = rect.origin.x
                let windowY = screenFrame.height - rect.origin.y - windowHeight
                window.setFrameOrigin(NSPoint(x: windowX, y: max(0, windowY)))
            } else {
                window.center()
            }

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.resultWindow = window
        }
    }

    func updateImage(_ image: NSImage) {
        translatedImage = image
        currentImage = image
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.resultWindow else { return }
            window.contentView = NSHostingView(rootView: ScreenshotView(
                image: image,
                isTranslating: false,
                onCopy: { self.copyToClipboard() },
                onClose: { self.close() }
            ))
        }
    }

    func close() {
        DispatchQueue.main.async { [weak self] in
            self?.resultWindow?.orderOut(nil)
            self?.resultWindow = nil
            self?.currentImage = nil
            self?.originalImage = nil
            self?.translatedImage = nil
        }
    }

    private func copyToClipboard() {
        guard let image = currentImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

// MARK: - Screenshot + Toolbar View

private struct ScreenshotView: View {
    let image: NSImage
    var isTranslating: Bool = false
    let onCopy: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 截图内容
            Image(nsImage: image)
                .frame(width: image.size.width, height: image.size.height)
                .overlay(alignment: .bottomTrailing) {
                    if isTranslating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Translating...")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(8)
                    }
                }

            // 底部工具栏
            HStack(spacing: 12) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close")
            }
            .font(.system(size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 36)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
    }
}
