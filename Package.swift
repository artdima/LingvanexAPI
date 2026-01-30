// swift-tools-version: 6.0

import PackageDescription

// Language mode stays at v5 until the client is immutable and Sendable;
// the switch to v6 is a separate, verifiable step.
let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "LingvanexAPI",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "LingvanexAPI", targets: ["LingvanexAPI"])
    ],
    targets: [
        .target(
            name: "LingvanexAPI",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "LingvanexAPITests",
            dependencies: ["LingvanexAPI"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        )
    ]
)
