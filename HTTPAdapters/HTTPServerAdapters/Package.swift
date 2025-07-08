// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPServerAdapters",
    platforms: [
        .iOS(.v15),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTTPServerAdapters",
            targets: ["HTTPServerAdapters"]
        ),
    ],
    dependencies: [
        // Core shared interfaces
        .package(path: "../HTTPServerAdaptersCore"),
        // Only include V2 to avoid dependency conflicts
        .package(path: "../HTTPServerAdaptersV2"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdapters",
            dependencies: [
                .product(name: "HTTPServerAdaptersCore", package: "HTTPServerAdaptersCore"),
                .product(name: "HTTPServerAdaptersV2", package: "HTTPServerAdaptersV2"),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersTests",
            dependencies: ["HTTPServerAdapters"]
        ),
    ]
)