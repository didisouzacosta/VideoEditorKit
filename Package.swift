// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VideoEditorKit",
    platforms: [
        .iOS(.v26)
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
