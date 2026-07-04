import SwiftUI

struct MenuBarView: View {
    @State private var isTranslating = false
    @State private var lastError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ImageTranslator")
                .font(.headline)

            Divider()

            Button(action: startTranslation) {
                Label("Start Translation", systemImage: "text.viewfinder")
            }
            .disabled(isTranslating)

            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }

            Button(action: quitApp) {
                Label("Quit", systemImage: "power")
            }

            if isTranslating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Translating...")
                        .font(.caption)
                }
            }

            if let error = lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }

    private func startTranslation() {
        isTranslating = true
        lastError = nil
        // TODO: Implement actual translation logic
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isTranslating = false
        }
    }

    private func openSettings() {
        // TODO: implement
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MenuBarView()
}
