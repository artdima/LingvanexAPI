// swift-tools-version: 6.0

import PackageDescription

// Language mode stays at v5 until the client is Sendable end to end;
// the switch to v6 is a separate, verifiable step.
let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "LingvanexAPI",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
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
