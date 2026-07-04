# ImageTranslator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app that captures screen regions, performs OCR + translation, and overlays translated text on original positions.

**Architecture:** Modular SwiftUI app with pluggable OCR/Translation providers. Screen capture → OCR → Translation → Render pipeline.

**Tech Stack:** Swift, SwiftUI, AppKit, Vision framework, Core Graphics, Google Translate API

---

## File Structure

```
ImageTranslator/
├── App/
│   ├── AppDelegate.swift              # Menu bar setup, global hotkey
│   ├── ImageTranslatorApp.swift       # SwiftUI App entry point
│   └── MenuBarView.swift              # Menu bar dropdown UI
├── Modules/
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift # Screen capture logic
│   │   └── CaptureOverlayView.swift   # Selection overlay UI
│   ├── OCR/
│   │   ├── OCRProvider.swift          # Protocol definition
│   │   └── VisionOCR.swift            # Apple Vision implementation
│   ├── Translation/
│   │   ├── TranslationProvider.swift  # Protocol definition
│   │   ├── GoogleTranslator.swift     # Google Translate implementation
│   │   └── TranslatorFactory.swift    # Factory for creating translators
│   └── Renderer/
│       └── TranslationRenderer.swift  # Text overlay rendering
├── Services/
│   ├── ConfigManager.swift            # App configuration
│   └── HotKeyManager.swift            # Global hotkey registration
├── Utils/
│   └── ImageUtils.swift               # Image processing helpers
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

## Task 1: Project Setup & App Entry Point

**Files:**
- Create: `ImageTranslator/ImageTranslatorApp.swift`
- Create: `ImageTranslator/App/AppDelegate.swift`
- Create: `ImageTranslator/Resources/Info.plist`

- [ ] **Step 1: Create Xcode project**

Open Xcode → New Project → macOS → App
- Product Name: ImageTranslator
- Interface: SwiftUI
- Language: Swift
- Bundle Identifier: com.mimo.imagetranslator

- [ ] **Step 2: Configure Info.plist for menu bar app**

Add to Info.plist:
```xml
<key>LSUIElement</key>
<true/>
<key>LSBackgroundOnly</key>
<false/>
```

- [ ] **Step 3: Create AppDelegate.swift**

```swift
import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "translate", accessibilityDescription: "ImageTranslator")
            button.action = #selector(togglePopover)
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
```

- [ ] **Step 4: Create ImageTranslatorApp.swift**

```swift
import SwiftUI

@main
struct ImageTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 5: Build and verify app appears in menu bar**

Run: `⌘R`
Expected: App launches, icon appears in menu bar, click shows empty popover

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: initial project setup with menu bar app"
```

---

## Task 2: Menu Bar UI

**Files:**
- Create: `ImageTranslator/App/MenuBarView.swift`

- [ ] **Step 1: Create MenuBarView.swift**

```swift
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
            
            if isTranslating {
                ProgressView("Processing...")
                    .progressViewStyle(.linear)
            }
            
            Divider()
            
            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }
            
            Button(action: quitApp) {
                Label("Quit", systemImage: "power")
            }
            
            if let error = lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 280)
    }
    
    private func startTranslation() {
        isTranslating = true
        lastError = nil
        // Will be implemented in Task 4
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isTranslating = false
        }
    }
    
    private func openSettings() {
        // Will be implemented in Task 7
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MenuBarView()
}
```

- [ ] **Step 2: Build and test UI**

Run: `⌘R`
Expected: Click menu bar icon, popover shows with "Start Translation", "Settings", "Quit" buttons

- [ ] **Step 3: Commit**

```bash
git add ImageTranslator/App/MenuBarView.swift
git commit -m "feat: add menu bar dropdown UI"
```

---

## Task 3: OCR Provider Protocol & Vision Implementation

**Files:**
- Create: `ImageTranslator/Modules/OCR/OCRProvider.swift`
- Create: `ImageTranslator/Modules/OCR/VisionOCR.swift`

- [ ] **Step 1: Create OCRProvider protocol**

```swift
import Foundation
import CoreGraphics

struct TextBlock: Identifiable {
    let id = UUID()
    let text: String
    let rect: CGRect
    let confidence: Float
}

enum OCRError: Error {
    case recognitionFailed
    case noTextFound
    case invalidImage
}

protocol OCRProvider {
    func recognize(image: CGImage) async throws -> [TextBlock]
}
```

- [ ] **Step 2: Create VisionOCR implementation**

```swift
import Vision
import CoreGraphics

class VisionOCR: OCRProvider {
    func recognize(image: CGImage) async throws -> [TextBlock] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.recognitionFailed)
                    return
                }
                
                let textBlocks = observations.compactMap { observation -> TextBlock? in
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    
                    let boundingBox = observation.boundingBox
                    let rect = CGRect(
                        x: boundingBox.origin.x * CGFloat(image.width),
                        y: (1 - boundingBox.origin.y - boundingBox.height) * CGFloat(image.height),
                        width: boundingBox.width * CGFloat(image.width),
                        height: boundingBox.height * CGFloat(image.height)
                    )
                    
                    return TextBlock(
                        text: topCandidate.string,
                        rect: rect,
                        confidence: topCandidate.confidence
                    )
                }
                
                continuation.resume(returning: textBlocks)
            }
            
            request.recognitionLanguages = ["en-US", "zh-Hans", "zh-Hant"]
            request.recognitionLevel = .accurate
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

- [ ] **Step 3: Create unit test for VisionOCR**

Create `ImageTranslatorTests/OCRTests.swift`:
```swift
import XCTest
@testable import ImageTranslator

final class OCRTests: XCTestCase {
    func testTextBlockStructure() {
        let block = TextBlock(
            text: "Hello World",
            rect: CGRect(x: 0, y: 0, width: 100, height: 50),
            confidence: 0.95
        )
        
        XCTAssertEqual(block.text, "Hello World")
        XCTAssertEqual(block.rect.width, 100)
        XCTAssertEqual(block.confidence, 0.95)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `⌘U`
Expected: Test passes

- [ ] **Step 5: Commit**

```bash
git add ImageTranslator/Modules/OCR/ ImageTranslatorTests/OCRTests.swift
git commit -m "feat: add OCR provider protocol and Vision implementation"
```

---

## Task 4: Translation Provider Protocol & Google Implementation

**Files:**
- Create: `ImageTranslator/Modules/Translation/TranslationProvider.swift`
- Create: `ImageTranslator/Modules/Translation/GoogleTranslator.swift`
- Create: `ImageTranslator/Modules/Translation/TranslatorFactory.swift`

- [ ] **Step 1: Create TranslationProvider protocol**

```swift
import Foundation

enum TranslationError: Error {
    case invalidResponse
    case rateLimitExceeded
    case networkError
    case apiKeyMissing
}

protocol TranslationProvider {
    var name: String { get }
    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String]
}

extension TranslationProvider {
    func translateBatch(_ texts: [String], from sourceLang: String, to targetLang: String) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let translated = try await translate(text, from: sourceLang, to: targetLang)
            results.append(translated)
        }
        return results
    }
}
```

- [ ] **Step 2: Create GoogleTranslator implementation**

```swift
import Foundation

class GoogleTranslator: TranslationProvider {
    let name = "Google Translate"
    private let apiKey: String?
    
    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    func translate(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw TranslationError.apiKeyMissing
        }
        
        let urlString = "https://translation.googleapis.com/language/translate/v2"
        guard var urlComponents = URLComponents(string: urlString) else {
            throw TranslationError.invalidResponse
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "source", value: sourceLang),
            URLQueryItem(name: "target", value: targetLang),
            URLQueryItem(name: "format", value: "text")
        ]
        
        guard let url = urlComponents.url else {
            throw TranslationError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.networkError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let dataObj = json?["data"] as? [String: Any]
        let translations = dataObj?["translations"] as? [[String: Any]]
        let firstTranslation = translations?.first?["translatedText"] as? String
        
        guard let translatedText = firstTranslation else {
            throw TranslationError.invalidResponse
        }
        
        return translatedText
    }
}
```

- [ ] **Step 3: Create TranslatorFactory**

```swift
import Foundation

enum TranslationEngine: String, CaseIterable {
    case google = "Google"
    case deepl = "DeepL"
    case localAI = "Local AI"
}

class TranslatorFactory {
    static func create(engine: TranslationEngine, config: ConfigManager) -> TranslationProvider {
        switch engine {
        case .google:
            return GoogleTranslator(apiKey: config.googleAPIKey)
        case .deepl:
            // Placeholder for DeepL implementation
            fatalError("DeepL not yet implemented")
        case .localAI:
            // Placeholder for local AI implementation
            fatalError("Local AI not yet implemented")
        }
    }
}
```

- [ ] **Step 4: Create unit test for GoogleTranslator**

Create `ImageTranslatorTests/TranslationTests.swift`:
```swift
import XCTest
@testable import ImageTranslator

final class TranslationTests: XCTestCase {
    func testTranslatorFactoryCreatesGoogleTranslator() {
        let config = ConfigManager()
        let translator = TranslatorFactory.create(engine: .google, config: config)
        XCTAssertTrue(translator is GoogleTranslator)
    }
}
```

- [ ] **Step 5: Run tests**

Run: `⌘U`
Expected: Test passes

- [ ] **Step 6: Commit**

```bash
git add ImageTranslator/Modules/Translation/ ImageTranslatorTests/TranslationTests.swift
git commit -m "feat: add translation provider protocol and Google implementation"
```

---

## Task 5: Translation Renderer

**Files:**
- Create: `ImageTranslator/Modules/Renderer/TranslationRenderer.swift`
- Create: `ImageTranslator/Utils/ImageUtils.swift`

- [ ] **Step 1: Create ImageUtils.swift**

```swift
import CoreGraphics
import AppKit

extension CGImage {
    var size: CGSize {
        CGSize(width: width, height: height)
    }
    
    func toNSImage() -> NSImage {
        NSImage(cgImage: self, size: size)
    }
}

extension NSImage {
    func toCGImage() -> CGImage? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
```

- [ ] **Step 2: Create TranslationRenderer.swift**

```swift
import CoreGraphics
import AppKit

class TranslationRenderer {
    private let overlayColor: NSColor
    private let textColor: NSColor
    private let fontSizeRatio: CGFloat
    private let padding: CGFloat
    
    init(
        overlayColor: NSColor = .white,
        textColor: NSColor = .black,
        fontSizeRatio: CGFloat = 0.65,
        padding: CGFloat = 2
    ) {
        self.overlayColor = overlayColor
        self.textColor = textColor
        self.fontSizeRatio = fontSizeRatio
        self.padding = padding
    }
    
    func render(
        originalImage: CGImage,
        textBlocks: [TextBlock],
        translations: [String]
    ) -> CGImage? {
        let width = originalImage.width
        let height = originalImage.height
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        context.draw(originalImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        for (index, block) in textBlocks.enumerated() {
            guard index < translations.count else { break }
            let translation = translations[index]
            drawOverlay(context: context, block: block, text: translation)
        }
        
        return context.makeImage()
    }
    
    private func drawOverlay(context: CGContext, block: TextBlock, text: String) {
        let rect = block.rect
        
        context.setFillColor(overlayColor.cgColor)
        context.fill(rect)
        
        let fontSize = calculateFontSize(for: text, in: rect)
        let font = NSFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        let lines = wrapText(text, font: font, maxWidth: rect.width - padding * 2)
        let lineHeight = fontSize * 1.2
        let totalHeight = CGFloat(lines.count) * lineHeight
        let startY = rect.midY + totalHeight / 2 - lineHeight
        
        for (lineIndex, line) in lines.enumerated() {
            let lineSize = (line as NSString).size(withAttributes: attributes)
            let lineX = rect.midX - lineSize.width / 2
            let lineY = startY - CGFloat(lineIndex) * lineHeight
            
            let lineRect = CGRect(
                x: lineX,
                y: lineY - lineSize.height / 2,
                width: lineSize.width,
                height: lineSize.height
            )
            
            (line as NSString).draw(in: lineRect, withAttributes: attributes)
        }
    }
    
    private func calculateFontSize(for text: String, in rect: CGRect) -> CGFloat {
        let maxHeight = rect.height * fontSizeRatio
        var fontSize = maxHeight
        let font = NSFont.systemFont(ofSize: fontSize)
        let size = (text as NSString).size(withAttributes: [.font: font])
        
        if size.width > rect.width - padding * 2 {
            let ratio = (rect.width - padding * 2) / size.width
            fontSize *= ratio
        }
        
        return max(fontSize, 8)
    }
    
    private func wrapText(_ text: String, font: NSFont, maxWidth: CGFloat) -> [String] {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = ""
        
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            let size = (testLine as NSString).size(withAttributes: [.font: font])
            
            if size.width > maxWidth && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }
        
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        
        return lines.isEmpty ? [text] : lines
    }
}
```

- [ ] **Step 3: Create unit test for renderer**

Create `ImageTranslatorTests/RendererTests.swift`:
```swift
import XCTest
@testable import ImageTranslator

final class RendererTests: XCTestCase {
    func testRendererInitialization() {
        let renderer = TranslationRenderer()
        XCTAssertNotNil(renderer)
    }
    
    func testRendererWithCustomColors() {
        let renderer = TranslationRenderer(
            overlayColor: .lightGray,
            textColor: .darkGray,
            fontSizeRatio: 0.7
        )
        XCTAssertNotNil(renderer)
    }
}
```

- [ ] **Step 4: Run tests**

Run: `⌘U`
Expected: Tests pass

- [ ] **Step 5: Commit**

```bash
git add ImageTranslator/Modules/Renderer/ ImageTranslator/Utils/ ImageTranslatorTests/RendererTests.swift
git commit -m "feat: add translation renderer with auto font sizing"
```

---

## Task 6: Screen Capture Module

**Files:**
- Create: `ImageTranslator/Modules/Capture/ScreenCaptureManager.swift`
- Create: `ImageTranslator/Modules/Capture/CaptureOverlayView.swift`

- [ ] **Step 1: Create ScreenCaptureManager.swift**

```swift
import Cocoa
import CoreGraphics

class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    private var captureWindow: NSWindow?
    private var onComplete: ((CGImage?) -> Void)?
    
    func startCapture(onComplete: @escaping (CGImage?) -> Void) {
        self.onComplete = onComplete
        
        guard let screen = NSScreen.main else {
            onComplete(nil)
            return
        }
        
        let overlay = CaptureOverlayView(
            onSelectionComplete: { [weak self] rect in
                self?.performCapture(rect: rect, screen: screen)
            },
            onCancel: { [weak self] in
                self?.cleanup()
            }
        )
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.contentView = NSHostingView(rootView: overlay)
        window.makeKeyAndOrderFront(nil)
        
        captureWindow = window
    }
    
    private func performCapture(rect: CGRect, screen: NSScreen) {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGMainDisplayID()
        
        guard let image = CGDisplayCreateImage(displayID, rect: rect) else {
            cleanup()
            onComplete?(nil)
            return
        }
        
        cleanup()
        onComplete?(image)
    }
    
    private func cleanup() {
        captureWindow?.orderOut(nil)
        captureWindow = nil
    }
}
```

- [ ] **Step 2: Create CaptureOverlayView.swift**

```swift
import SwiftUI

struct CaptureOverlayView: View {
    let onSelectionComplete: (CGRect) -> Void
    let onCancel: () -> Void
    
    @State private var isDragging = false
    @State private var startLocation: CGPoint = .zero
    @State private var currentLocation: CGPoint = .zero
    
    var selectionRect: CGRect {
        let x = min(startLocation.x, currentLocation.x)
        let y = min(startLocation.y, currentLocation.y)
        let width = abs(currentLocation.x - startLocation.x)
        let height = abs(currentLocation.y - startLocation.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onCancel()
                    }
                
                if isDragging && selectionRect.width > 0 && selectionRect.height > 0 {
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(
                            x: selectionRect.midX,
                            y: selectionRect.midY
                        )
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: selectionRect.width, height: selectionRect.height)
                        .position(
                            x: selectionRect.midX,
                            y: selectionRect.midY
                        )
                }
                
                VStack {
                    Spacer()
                    Text("Drag to select area. Press ESC to cancel.")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    Spacer().frame(height: 50)
                }
            }
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    if event.keyCode == 53 {
                        self.onCancel()
                    }
                    return event
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if !isDragging {
                        startLocation = location
                    }
                    currentLocation = location
                case .ended:
                    break
                }
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        isDragging = true
                        currentLocation = value.location
                    }
                    .onEnded { value in
                        if selectionRect.width > 10 && selectionRect.height > 10 {
                            onSelectionComplete(selectionRect)
                        }
                        isDragging = false
                    }
            )
        }
    }
}
```

- [ ] **Step 3: Build and test capture**

Run: `⌘R`
Expected: Click "Start Translation" → Screen darkens → Drag to select → Selection rectangle appears

- [ ] **Step 4: Commit**

```bash
git add ImageTranslator/Modules/Capture/
git commit -m "feat: add screen capture with selection overlay"
```

---

## Task 7: Configuration Manager

**Files:**
- Create: `ImageTranslator/Services/ConfigManager.swift`

- [ ] **Step 1: Create ConfigManager.swift**

```swift
import Foundation
import AppKit

class ConfigManager: ObservableObject {
    static let shared = ConfigManager()
    
    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    
    @Published var translationEngine: TranslationEngine {
        didSet { UserDefaults.standard.set(translationEngine.rawValue, forKey: "translationEngine") }
    }
    
    @Published var overlayColor: NSColor {
        didSet {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: overlayColor, requiringSecureCoding: false) {
                UserDefaults.standard.set(data, forKey: "overlayColor")
            }
        }
    }
    
    @Published var autoTranslate: Bool {
        didSet { UserDefaults.standard.set(autoTranslate, forKey: "autoTranslate") }
    }
    
    @Published var googleAPIKey: String? {
        didSet { UserDefaults.standard.set(googleAPIKey, forKey: "googleAPIKey") }
    }
    
    init() {
        self.targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "zh-CN"
        
        let engineString = UserDefaults.standard.string(forKey: "translationEngine") ?? "Google"
        self.translationEngine = TranslationEngine(rawValue: engineString) ?? .google
        
        if let data = UserDefaults.standard.data(forKey: "overlayColor"),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            self.overlayColor = color
        } else {
            self.overlayColor = .white
        }
        
        self.autoTranslate = UserDefaults.standard.bool(forKey: "autoTranslate")
        self.googleAPIKey = UserDefaults.standard.string(forKey: "googleAPIKey")
    }
    
    func getTranslator() -> TranslationProvider {
        return TranslatorFactory.create(engine: translationEngine, config: self)
    }
}
```

- [ ] **Step 2: Build and verify config persists**

Run: `⌘R` → Change settings → Quit → Relaunch → Settings preserved

- [ ] **Step 3: Commit**

```bash
git add ImageTranslator/Services/ConfigManager.swift
git commit -m "feat: add configuration manager with UserDefaults persistence"
```

---

## Task 8: Main Translation Flow Integration

**Files:**
- Modify: `ImageTranslator/App/MenuBarView.swift`
- Modify: `ImageTranslator/App/AppDelegate.swift`

- [ ] **Step 1: Update MenuBarView with translation flow**

```swift
import SwiftUI

struct MenuBarView: View {
    @State private var isTranslating = false
    @State private var lastError: String?
    @State private var translatedImage: NSImage?
    
    private let config = ConfigManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ImageTranslator")
                .font(.headline)
            
            Divider()
            
            if let image = translatedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                
                Button(action: saveImage) {
                    Label("Save Image", systemImage: "square.and.arrow.down")
                }
                
                Button(action: { translatedImage = nil }) {
                    Label("Clear", systemImage: "xmark.circle")
                }
            } else {
                Button(action: startTranslation) {
                    Label("Start Translation", systemImage: "text.viewfinder")
                }
                .disabled(isTranslating)
            }
            
            if isTranslating {
                ProgressView("Processing...")
                    .progressViewStyle(.linear)
            }
            
            Divider()
            
            Button(action: openSettings) {
                Label("Settings", systemImage: "gear")
            }
            
            Button(action: quitApp) {
                Label("Quit", systemImage: "power")
            }
            
            if let error = lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    private func startTranslation() {
        isTranslating = true
        lastError = nil
        
        ScreenCaptureManager.shared.startCapture { [weak self] image in
            guard let self = self, let image = image else {
                DispatchQueue.main.async {
                    self?.isTranslating = false
                    self?.lastError = "Capture cancelled"
                }
                return
            }
            
            Task {
                await self.processImage(image)
            }
        }
    }
    
    private func processImage(_ image: CGImage) async {
        let ocr = VisionOCR()
        let renderer = TranslationRenderer()
        let translator = config.getTranslator()
        
        do {
            let textBlocks = try await ocr.recognize(image: image)
            
            guard !textBlocks.isEmpty else {
                await MainActor.run {
                    self.isTranslating = false
                    self.lastError = "No text found"
                }
                return
            }
            
            let texts = textBlocks.map { $0.text }
            let translations = try await translator.translateBatch(
                texts,
                from: "en",
                to: config.targetLanguage
            )
            
            guard let result = renderer.render(
                originalImage: image,
                textBlocks: textBlocks,
                translations: translations
            ) else {
                await MainActor.run {
                    self.isTranslating = false
                    self.lastError = "Rendering failed"
                }
                return
            }
            
            await MainActor.run {
                self.translatedImage = result.toNSImage()
                self.isTranslating = false
            }
        } catch {
            await MainActor.run {
                self.isTranslating = false
                self.lastError = error.localizedDescription
            }
        }
    }
    
    private func saveImage() {
        guard let image = translatedImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "translated.png"
        
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
    
    private func openSettings() {
        // Will be implemented in Task 9
    }
    
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

#Preview {
    MenuBarView()
}
```

- [ ] **Step 2: Build and test full flow**

Run: `⌘R`
Expected: Click "Start Translation" → Select area → OCR processes → Translation appears → Can save

- [ ] **Step 3: Commit**

```bash
git add ImageTranslator/App/
git commit -m "feat: integrate full translation flow in menu bar UI"
```

---

## Task 9: Settings Window

**Files:**
- Create: `ImageTranslator/App/SettingsView.swift`

- [ ] **Step 1: Create SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var config = ConfigManager.shared
    @State private var showingAPIKeyAlert = false
    
    var body: some View {
        Form {
            Section("Translation") {
                Picker("Target Language", selection: $config.targetLanguage) {
                    Text("Chinese (Simplified)").tag("zh-CN")
                    Text("Chinese (Traditional)").tag("zh-TW")
                    Text("Japanese").tag("ja")
                    Text("Korean").tag("ko")
                    Text("English").tag("en")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Spanish").tag("es")
                }
                
                Picker("Translation Engine", selection: $config.translationEngine) {
                    ForEach(TranslationEngine.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                
                Toggle("Auto Translate", isOn: $config.autoTranslate)
            }
            
            Section("API Keys") {
                HStack {
                    TextField("Google API Key", text: Binding(
                        get: { config.googleAPIKey ?? "" },
                        set: { config.googleAPIKey = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Button(action: { showingAPIKeyAlert = true }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            
            Section("Appearance") {
                ColorPicker("Overlay Color", selection: $config.overlayColor)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .alert("API Key", isPresented: $showingAPIKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Get your Google Translate API key from Google Cloud Console.")
        }
    }
}

#Preview {
    SettingsView()
}
```

- [ ] **Step 2: Update AppDelegate to show settings window**

Add to AppDelegate.swift:
```swift
var settingsWindow: NSWindow?

func openSettings() {
    if settingsWindow == nil {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow?.title = "ImageTranslator Settings"
        settingsWindow?.styleMask = [.titled, .closable]
        settingsWindow?.center()
    }
    
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **Step 3: Update MenuBarView to use AppDelegate for settings**

Update MenuBarView.swift:
```swift
private func openSettings() {
    NSApp.delegate?.openSettings?()
}
```

- [ ] **Step 4: Build and test settings**

Run: `⌘R` → Click "Settings" → Change language → Quit → Relaunch → Language preserved

- [ ] **Step 5: Commit**

```bash
git add ImageTranslator/App/SettingsView.swift ImageTranslator/App/AppDelegate.swift
git commit -m "feat: add settings window with language and API key configuration"
```

---

## Task 10: HotKey Support

**Files:**
- Create: `ImageTranslator/Services/HotKeyManager.swift`

- [ ] **Step 1: Create HotKeyManager.swift**

```swift
import Cocoa
import Carbon.HIToolbox

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var onHotKey: (() -> Void)?
    
    func register(combo: (key: UInt32, modifiers: UInt32), onAction: @escaping () -> Void) {
        self.onHotKey = onAction
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = 0x494D4754 // "IMG T"
        hotKeyID.id = 1
        
        let modifierFlags = modifierToCarbon(combo.modifiers)
        
        RegisterEventHotKey(
            combo.key,
            modifierFlags,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                NotificationCenter.default.post(name: .hotKeyTriggered, object: nil)
                return noErr
            },
            1,
            &eventSpec,
            nil,
            nil
        )
        
        NotificationCenter.default.addObserver(
            forName: .hotKeyTriggered,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onHotKey?()
        }
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
    
    private func modifierToCarbon(_ modifiers: UInt32) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if modifiers & UInt32(NSEvent.ModifierFlags.control.rawValue) != 0 {
            carbonFlags |= UInt32(cmdKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.option.rawValue) != 0 {
            carbonFlags |= UInt32(optionKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.command.rawValue) != 0 {
            carbonFlags |= UInt32(cmdKey)
        }
        if modifiers & UInt32(NSEvent.ModifierFlags.shift.rawValue) != 0 {
            carbonFlags |= UInt32(shiftKey)
        }
        return carbonFlags
    }
}

extension Notification.Name {
    static let hotKeyTriggered = Notification.Name("hotKeyTriggered")
}
```

- [ ] **Step 2: Register hot key in AppDelegate**

Add to AppDelegate.swift:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing code ...
    
    HotKeyManager.shared.register(
        combo: (key: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | commandKey)),
        onAction: { [weak self] in
            self?.startTranslationFromHotKey()
        }
    )
}

func startTranslationFromHotKey() {
    NotificationCenter.default.post(name: .startTranslation, object: nil)
}
```

- [ ] **Step 3: Listen for hot key notification in MenuBarView**

Add to MenuBarView.swift:
```swift
.onReceive(NotificationCenter.default.publisher(for: .startTranslation)) { _ in
    startTranslation()
}
```

- [ ] **Step 4: Build and test hot key**

Run: `⌘R` → Press `⌃⌘T` → Capture overlay appears

- [ ] **Step 5: Commit**

```bash
git add ImageTranslator/Services/HotKeyManager.swift ImageTranslator/App/AppDelegate.swift
git commit -m "feat: add global hotkey (⌃⌘T) for quick translation"
```

---

## Task 11: Error Handling & Polish

**Files:**
- Modify: `ImageTranslator/Modules/Capture/ScreenCaptureManager.swift`
- Modify: `ImageTranslator/App/MenuBarView.swift`

- [ ] **Step 1: Add error handling to ScreenCaptureManager**

Update ScreenCaptureManager.swift:
```swift
enum CaptureError: LocalizedError {
    case noScreen
    case captureFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .noScreen:
            return "No screen available"
        case .captureFailed:
            return "Screen capture failed"
        case .permissionDenied:
            return "Screen recording permission required"
        }
    }
}

class ScreenCaptureManager {
    // ... existing code ...
    
    func startCapture(onComplete: @escaping (Result<CGImage, CaptureError>) -> Void) {
        guard let screen = NSScreen.main else {
            onComplete(.failure(.noScreen))
            return
        }
        
        // Check screen recording permission
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            onComplete(.failure(.permissionDenied))
            return
        }
        
        // ... rest of implementation ...
    }
}
```

- [ ] **Step 2: Update MenuBarView to handle errors**

```swift
private func processImage(_ image: CGImage) async {
    // ... existing code ...
    
    ScreenCaptureManager.shared.startCapture { [weak self] result in
        guard let self = self else { return }
        
        switch result {
        case .success(let image):
            Task {
                await self.processImage(image)
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.isTranslating = false
                self.lastError = error.localizedDescription
            }
        }
    }
}
```

- [ ] **Step 3: Build and test error handling**

Run: `⌘R` → Deny screen recording permission → Try to capture → Error message shown

- [ ] **Step 4: Commit**

```bash
git add ImageTranslator/Modules/Capture/ScreenCaptureManager.swift ImageTranslator/App/MenuBarView.swift
git commit -m "feat: add comprehensive error handling"
```

---

## Task 12: Final Integration & Testing

- [ ] **Step 1: Run all tests**

Run: `⌘U`
Expected: All tests pass

- [ ] **Step 2: Build release version**

Run: `⌘B` with Release configuration
Expected: App builds successfully

- [ ] **Step 3: Test complete flow**

1. Launch app
2. Click menu bar icon
3. Click "Start Translation"
4. Select area with text
5. Verify translation appears
6. Save image
7. Test hot key `⌃⌘T`
8. Open settings and change language
9. Quit and relaunch - settings persist

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: ImageTranslator v1.0 - complete implementation"
```

---

## Summary

| Task | Description | Est. Time |
|------|-------------|-----------|
| 1 | Project Setup | 10 min |
| 2 | Menu Bar UI | 15 min |
| 3 | OCR Provider | 30 min |
| 4 | Translation Provider | 30 min |
| 5 | Renderer | 45 min |
| 6 | Screen Capture | 45 min |
| 7 | Config Manager | 15 min |
| 8 | Integration | 30 min |
| 9 | Settings Window | 20 min |
| 10 | HotKey Support | 30 min |
| 11 | Error Handling | 20 min |
| 12 | Final Testing | 20 min |

**Total estimated time: ~5 hours**
