// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "A-Shot",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "A-Shot",
            path: "Sources/Shot",
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
