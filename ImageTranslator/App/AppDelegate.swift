import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    private let ocrProvider = VisionOCR()
    private let renderer = TranslationRenderer()
    private let configManager = ConfigManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HotKeyManager.shared.register()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotKey),
            name: HotKeyManager.hotKeyTriggeredNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
    }

    private var isCapturing = false

    @objc private func handleHotKey() {
        guard !isCapturing else { return }
        isCapturing = true
        ScreenCaptureManager.shared.startCapture { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let captureResult):
                let cgImage = captureResult.image
                let logicalSize = NSSize(width: captureResult.screenRect.width, height: captureResult.screenRect.height)
                let nsImg = NSImage(cgImage: cgImage, size: logicalSize)
                DispatchQueue.main.async {
                    self.isCapturing = false
                    ResultWindowManager.shared.show(image: nsImg, near: captureResult.screenRect)
                }
                Task {
                    await self.processTranslation(cgImage, screenRect: captureResult.screenRect)
                }
            case .failure:
                DispatchQueue.main.async {
                    self.isCapturing = false
                }
            }
        }
    }

    private func processTranslation(_ image: CGImage, screenRect: CGRect?) async {
        do {
            let textBlocks = try await ocrProvider.recognize(image: image)
            let texts = textBlocks.map { $0.text }
            guard !texts.isEmpty else { return }

            let translator = configManager.getTranslator()
            let translations: [String]
            do {
                translations = try await translator.translateBatch(
                    texts,
                    from: configManager.sourceLanguage,
                    to: configManager.targetLanguage
                )
            } catch {
                translations = try await fallbackTranslate(texts: texts, from: configManager.sourceLanguage, to: configManager.targetLanguage)
            }

            guard let rendered = renderer.render(originalImage: image, textBlocks: textBlocks, translations: translations) else { return }

            let logicalSize = screenRect.map { NSSize(width: $0.width, height: $0.height) }
                ?? NSSize(width: image.width, height: image.height)
            let nsResult = NSImage(cgImage: rendered, size: logicalSize)
            await MainActor.run {
                ResultWindowManager.shared.updateImage(nsResult)
            }
        } catch {
        }
    }

    private func fallbackTranslate(texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        let session = URLSession.shared
        let combinedText = texts.joined(separator: "\n")
        let escaped = combinedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? combinedText
        let urlString = "https://api.mymemory.translated.net/get?q=\(escaped)&langpair=\(sourceLang)|\(targetLang)"
        guard let url = URL(string: urlString) else { return texts }
        let (data, _) = try await session.data(from: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseData = json["responseData"] as? [String: Any],
           let translatedText = responseData["translatedText"] as? String {
            let decoded = translatedText.removingPercentEncoding ?? translatedText
            return decoded.components(separatedBy: "\n")
        }
        return texts
    }

    // MARK: - Status Bar & Popover

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let sfSymbol = NSImage(systemSymbolName: "translate", accessibilityDescription: "ImageTranslator") {
                button.image = sfSymbol
            } else {
                button.title = "T"
            }
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ImageTranslator Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}

extension Notification.Name {
    static let menuBarStartTranslation = Notification.Name("menuBarStartTranslation")
}
