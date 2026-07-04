import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var isInitialized = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        
        // Delay hotkey registration to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HotKeyManager.shared.register()
            self.isInitialized = true
            print("[DEBUG] App initialized, hotkey registered")
        }
        
        // Listen for hotkey and show popover
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
        print("[DEBUG] Hotkey received, starting capture")
        
        // Check permission first
        guard CGPreflightScreenCaptureAccess() else {
            print("[DEBUG] Permission not granted")
            return
        }
        
        // Start capture directly
        ScreenCaptureManager.shared.startCapture { [weak self] result in
            switch result {
            case .success(let image):
                print("[DEBUG] Capture success, processing...")
                self?.processCapturedImage(image)
            case .failure(let error):
                print("[DEBUG] Capture failed: \(error)")
            }
        }
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
                    
                    // Show popover with result
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
        // Create a result view
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


