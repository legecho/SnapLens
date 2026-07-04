import SwiftUI
import AppKit

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var captureWindow: NSWindow?

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

    @objc private func handleHotKey() {
        startCapture()
    }

    func startCapture() {
        print("[DEBUG] Starting capture")
        guard let fullImage = ScreenCaptureManager.shared.captureFullScreen() else {
            print("[DEBUG] Capture failed")
            return
        }
        ScreenCaptureManager.shared.saveDebugImage(fullImage, prefix: "fullscreen")
        showCaptureWindow(fullImage)
    }

    private func showCaptureWindow(_ image: CGImage) {
        let captureView = ScreenCaptureView(
            fullImage: image,
            onRegionSelected: { [weak self] rect in
                self?.closeCaptureWindow()
                if let cropped = ScreenCaptureManager.shared.cropImage(image, rect: rect) {
                    ScreenCaptureManager.shared.saveDebugImage(cropped, prefix: "cropped")
                    self?.processCapturedImage(cropped)
                }
            },
            onCancel: { [weak self] in
                self?.closeCaptureWindow()
            }
        )

        let window = OverlayWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.contentView = NSHostingView(rootView: captureView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.makeKeyAndOrderFront(nil)
        captureWindow = window
    }

    private func closeCaptureWindow() {
        captureWindow?.orderOut(nil)
        captureWindow = nil
    }

    private func processCapturedImage(_ image: CGImage) {
        print("[DEBUG] processCapturedImage: \(image.width)x\(image.height)")
        let ocrProvider = VisionOCR()
        let renderer = TranslationRenderer()
        let config = ConfigManager.shared

        Task {
            do {
                let textBlocks = try await ocrProvider.recognize(image: image)
                print("[DEBUG] OCR found \(textBlocks.count) blocks")
                let texts = textBlocks.map { $0.text }
                print("[DEBUG] texts: \(texts)")
                
                let translations = try await config.getTranslator().translateBatch(
                    texts,
                    from: "auto",
                    to: config.targetLanguage
                )
                print("[DEBUG] translations: \(translations)")
                
                if let rendered = renderer.render(originalImage: image, textBlocks: textBlocks, translations: translations) {
                    print("[DEBUG] render success")
                    let nsImage = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
                    await MainActor.run {
                        self.showResultPopover(image: nsImage)
                    }
                } else {
                    print("[DEBUG] render failed")
                }
            } catch {
                print("[DEBUG] Error: \(error)")
            }
        }
    }

    private func showResultPopover(image: NSImage) {
        popover.contentViewController = NSHostingController(rootView: TranslationResultView(image: image))
        showPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "translate", accessibilityDescription: "ImageTranslator")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}

extension Notification.Name {
    static let hotKeyTriggered = Notification.Name("hotKeyTriggered")
}
