import SwiftUI

struct TranslationResultView: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Translation Result")
                .font(.headline)
            
            Divider()
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(4)
            
            HStack {
                Button(action: saveImage) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                
                Button(action: { dismiss() }) {
                    Label("Close", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 300, height: 280)
    }
    
    private func saveImage() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "translated_\(Int(Date().timeIntervalSince1970)).png"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
}
