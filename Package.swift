// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReelsmithCore",
    products: [.library(name: "ReelsmithCore", targets: ["ReelsmithCore"])],
    targets: [
        .target(name: "ReelsmithCore"),
        .testTarget(name: "ReelsmithCoreTests", dependencies: ["ReelsmithCore"]),
    ]
)
