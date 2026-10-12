// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReelsmithCore",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [
        .library(name: "ReelsmithCore", targets: ["ReelsmithCore"]),
        .library(name: "ReelsmithEngine", targets: ["ReelsmithEngine"]),
    ],
    targets: [
        .target(name: "ReelsmithCore"),
        .testTarget(name: "ReelsmithCoreTests", dependencies: ["ReelsmithCore"]),
        .target(
            name: "ReelsmithEngine", dependencies: ["ReelsmithCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "ReelsmithEngineTests", dependencies: ["ReelsmithCore", "ReelsmithEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
