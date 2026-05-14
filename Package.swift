// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iQuit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "iQuit", targets: ["iQuit"]),
        .library(name: "iQuitCore", targets: ["iQuitCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        .target(
            name: "iQuitCore"
        ),
        .executableTarget(
            name: "iQuit",
            dependencies: [
                "iQuitCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "iQuitTests",
            dependencies: ["iQuitCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
