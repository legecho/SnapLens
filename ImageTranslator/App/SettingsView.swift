import SwiftUI

struct SettingsView: View {
    @ObservedObject private var config = ConfigManager.shared
    @State private var showAPIKeyHelp = false

    private let languages: [(code: String, name: String)] = [
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("en", "English"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ru", "Russian"),
        ("pt", "Portuguese"),
    ]

    var body: some View {
        Form {
            translationSection
            apiKeysSection
            appearanceSection
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 360)
        .alert("Google Cloud Translation API Key", isPresented: $showAPIKeyHelp) {
            Button("OK") {}
        } message: {
            Text("You need a Google Cloud project with the Cloud Translation API enabled.\n\nGet your API key from:\nconsole.cloud.google.com > APIs & Services > Credentials")
        }
    }

    private var translationSection: some View {
        Section("Translation") {
            Picker("Source Language", selection: $config.sourceLanguage) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }

            Picker("Target Language", selection: $config.targetLanguage) {
                ForEach(languages, id: \.code) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }

            Picker("Translation Engine", selection: $config.translationEngine) {
                ForEach(TranslationEngine.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }

            Toggle("Auto Translate", isOn: $config.autoTranslate)
        }
    }

    private var apiKeysSection: some View {
        Section("API Keys") {
            HStack {
                SecureField("Google API Key", text: Binding(
                    get: { config.googleAPIKey ?? "" },
                    set: { config.googleAPIKey = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)

                Button(action: { showAPIKeyHelp = true }) {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack {
                Text("Overlay Color")
                Spacer()
                ColorPicker("", selection: Binding(
                    get: { Color(config.overlayColor) },
                    set: { config.overlayColor = NSColor($0) }
                ))
                .labelsHidden()
            }
        }
    }
}

#Preview {
    SettingsView()
}
