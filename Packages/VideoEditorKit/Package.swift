// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VideoEditorKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "VideoEditorKit",
            targets: ["VideoEditorKit"]
        )
    ],
    targets: [
        .target(
            name: "VideoEditorKit",
            path: "Sources/VideoEditorKit"
        ),
        .testTarget(
            name: "VideoEditorKitTests",
            dependencies: ["VideoEditorKit"]
        ),
    ]
)
