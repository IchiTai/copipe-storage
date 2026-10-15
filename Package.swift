// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CopipeStorage",
    defaultLocalization: "ja",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CopipeCore", targets: ["CopipeCore"]),
        .executable(name: "CopipeStorage", targets: ["CopipeStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "3.1.0"),
    ],
    targets: [
        .target(name: "CopipeCore"),
        .executableTarget(
            name: "CopipeStorage",
            dependencies: [
                "CopipeCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "CopipeCoreTests", dependencies: ["CopipeCore"]),
    ]
)
