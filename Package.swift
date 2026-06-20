// swift-tools-version: 6.0

import Foundation
import PackageDescription

let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v6)]

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

// The documentation plugin is only needed to publish DocC from CI. Adding it
// unconditionally would make every consumer of this package resolve it too.
if ProcessInfo.processInfo.environment["LINGVANEX_BUILD_DOCS"] != nil {
    package.dependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
    )
}
