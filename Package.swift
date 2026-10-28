// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Marky",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "Marky", path: "Sources/Marky")
    ],
    swiftLanguageModes: [.v5]
)
