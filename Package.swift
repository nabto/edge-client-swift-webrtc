// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NabtoEdgeClientWebRTC",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NabtoEdgeClientWebRTC",
            targets: ["NabtoEdgeClientWebRTC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stasel/WebRTC.git", .upToNextMajor(from: "120.0.0")),
        .package(url: "https://github.com/nabto/edge-client-swift.git", branch: "spm-support"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NabtoEdgeClientWebRTC",
            dependencies: [
                "WebRTC",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "NabtoEdgeClient", package: "edge-client-swift")
            ]
        ),
        .testTarget(
            name: "NabtoEdgeClientWebRTCTests",
            dependencies: ["NabtoEdgeClientWebRTC"]),
    ]
)
