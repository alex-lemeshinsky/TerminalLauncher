// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LauncherKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "PathStore", targets: ["PathStore"]),
    ],
    targets: [
        .target(name: "PathStore"),
        .testTarget(name: "PathStoreTests", dependencies: ["PathStore"]),
    ]
)
