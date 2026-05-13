// swift-tools-version: 6.3
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
    targets: [
        .target(
            name: "iQuitCore"
        ),
        .executableTarget(
            name: "iQuit",
            dependencies: ["iQuitCore"]
        ),
        .testTarget(
            name: "iQuitTests",
            dependencies: ["iQuitCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
