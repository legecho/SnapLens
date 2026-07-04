import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
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
        popover.contentSize = NSSize(width: 320, height: 240)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverView())
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
}

struct PopoverView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "translate")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("ImageTranslator")
                .font(.headline)

            Text("Select a region to translate")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Button("Settings") {
                    // TODO: Open settings
                }
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.horizontal)
        }
        .padding(20)
        .frame(width: 320, height: 240)
    }
}
