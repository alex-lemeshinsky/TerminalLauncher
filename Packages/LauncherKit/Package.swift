// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LauncherKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "PathStore", targets: ["PathStore"]),
        .library(name: "TLCommands", targets: ["TLCommands"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "PathStore"),
        .target(
            name: "TLCommands",
            dependencies: [
                "PathStore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "PathStoreTests", dependencies: ["PathStore"]),
        .testTarget(name: "TLCommandsTests", dependencies: ["TLCommands", "PathStore"]),
    ]
)
