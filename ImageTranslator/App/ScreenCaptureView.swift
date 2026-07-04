import SwiftUI

struct ScreenCaptureView: View {
    let fullImage: CGImage
    let onRegionSelected: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?

    private var selectionRect: CGRect? {
        guard let start = dragStart, let end = dragEnd else { return nil }
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        guard width > 10, height > 10 else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var body: some View {
        GeometryReader { geometry in
            let imageAspect = CGFloat(fullImage.width) / CGFloat(fullImage.height)
            let viewAspect = geometry.size.width / geometry.size.height
            let displayWidth = imageAspect > viewAspect ? geometry.size.width : geometry.size.height * imageAspect
            let displayHeight = imageAspect > viewAspect ? geometry.size.width / imageAspect : geometry.size.height
            let offsetX = (geometry.size.width - displayWidth) / 2
            let offsetY = (geometry.size.height - displayHeight) / 2

            ZStack {
                Color.black.ignoresSafeArea()

                Image(nsImage: NSImage(cgImage: fullImage, size: NSSize(width: fullImage.width, height: fullImage.height)))
                    .resizable()
                    .frame(width: displayWidth, height: displayHeight)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                if let rect = selectionRect {
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    Rectangle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                VStack {
                    Spacer()
                    Text("在截图上框选要翻译的区域，按 ESC 取消")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragStart = dragStart ?? value.location
                        dragEnd = value.location
                    }
                    .onEnded { value in
                        guard let rect = selectionRect else { return }

                        let scaleX = CGFloat(fullImage.width) / displayWidth
                        let scaleY = CGFloat(fullImage.height) / displayHeight

                        let imageRect = CGRect(
                            x: (rect.origin.x - offsetX) * scaleX,
                            y: (rect.origin.y - offsetY) * scaleY,
                            width: rect.width * scaleX,
                            height: rect.height * scaleY
                        )
                        print("[DEBUG] view rect: \(rect) → image rect: \(imageRect)")
                        onRegionSelected(imageRect)
                    }
            )
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 { onCancel(); return nil }
                    return event
                }
            }
        }
    }
}
