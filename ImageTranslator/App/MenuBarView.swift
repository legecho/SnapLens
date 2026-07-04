import SwiftUI

struct MenuBarView: View {
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
        .frame(width: 300, height: 200)
    }
}
