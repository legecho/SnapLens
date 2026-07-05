import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        // 注册快捷键
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            HotKeyManager.shared.register()
        }

        // 监听快捷键通知
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
        ScreenCaptureManager.shared.startCapture { result in
            switch result {
            case .success(let captureResult):
                let cgImage = captureResult.image
                let logicalSize = NSSize(width: captureResult.screenRect.width, height: captureResult.screenRect.height)
                let nsImg = NSImage(cgImage: cgImage, size: logicalSize)
                DispatchQueue.main.async {
                    ResultWindowManager.shared.show(image: nsImg, near: captureResult.screenRect)
                }
            case .failure(let error):
                print("[DEBUG] hotkey capture failed: \(error)")
            }
        }
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
