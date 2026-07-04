import SwiftUI

struct CaptureOverlayView: View {
    let onSelectionComplete: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var isDragging = false

    private var selectionRect: CGRect? {
        guard let start = dragStart, let end = dragEnd else { return nil }
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                if let rect = selectionRect {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }

                VStack {
                    Spacer()

                    Text("Drag to select region. Press ESC to cancel.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        dragStart = dragStart ?? value.location
                        dragEnd = value.location
                    }
                    .onEnded { value in
                        guard let rect = selectionRect, rect.width > 10, rect.height > 10 else {
                            resetSelection()
                            return
                        }

                        let flippedRect = CGRect(
                            x: rect.origin.x,
                            y: geometry.size.height - rect.origin.y - rect.height,
                            width: rect.width,
                            height: rect.height
                        )
                        onSelectionComplete(flippedRect)
                    }
            )
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 {
                        self.onCancel()
                        return nil
                    }
                    return event
                }
            }
        }
    }

    private func resetSelection() {
        dragStart = nil
        dragEnd = nil
        isDragging = false
    }
}
