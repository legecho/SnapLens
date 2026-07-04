import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        HotKeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeyManager.shared.unregister()
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

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
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


