// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ImageTranslator",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ImageTranslator",
            path: "ImageTranslator",
            exclude: ["Resources"]
        )
    ]
)
