import SwiftUI
import AppKit

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
            print("[DEBUG] App initialized, hotkey registered")
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
        print("[DEBUG] Hotkey received")
        startCapture()
    }
    
    func startCapture() {
        print("[DEBUG] Starting capture")
        
        // 1. 先截全屏
        guard let fullImage = ScreenCaptureManager.shared.captureFullScreen() else {
            print("[DEBUG] Failed to capture screen")
            return
        }
        
        // 2. 保存调试图片
        ScreenCaptureManager.shared.saveDebugImage(fullImage, prefix: "fullscreen")
        
        // 3. 显示截图窗口让用户选区
        showCaptureWindow(fullImage)
    }
    
    private func showCaptureWindow(_ image: CGImage) {
        let captureView = ScreenCaptureView(
            fullImage: image,
            onRegionSelected: { [weak self] rect in
                self?.closeCaptureWindow()
                self?.processRegion(image, rect: rect)
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
    
    private func processRegion(_ fullImage: CGImage, rect: CGRect) {
        print("[DEBUG] Processing region: \(rect)")
        
        // 裁剪选区
        guard let cropped = fullImage.cropping(to: rect) else {
            print("[DEBUG] Failed to crop")
            return
        }
        
        print("[DEBUG] Cropped: \(cropped.width)x\(cropped.height)")
        ScreenCaptureManager.shared.saveDebugImage(cropped, prefix: "cropped")
        
        // OCR + 翻译
        processCapturedImage(cropped)
    }

    private func processCapturedImage(_ image: CGImage) {
        let ocrProvider = VisionOCR()
        let renderer = TranslationRenderer()
        let config = ConfigManager.shared
        
        Task {
            do {
                let textBlocks = try await ocrProvider.recognize(image: image)
                let texts = textBlocks.map { $0.text }
                let translations = try await config.getTranslator().translateBatch(
                    texts,
                    from: "auto",
                    to: config.targetLanguage
                )
                
                if let rendered = renderer.render(originalImage: image, textBlocks: textBlocks, translations: translations) {
                    let nsImage = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
                    await MainActor.run {
                        self.showResultPopover(image: nsImage)
                    }
                }
            } catch {
                print("[DEBUG] Processing error: \(error)")
            }
        }
    }
    
    private func showResultPopover(image: NSImage) {
        let resultView = TranslationResultView(image: image)
        popover.contentViewController = NSHostingController(rootView: resultView)
        showPopover()
    }

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
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
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
    static let hotKeyTriggered = Notification.Name("hotKeyTriggered")
}
