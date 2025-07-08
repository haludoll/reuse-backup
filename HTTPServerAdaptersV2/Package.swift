// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPServerAdaptersV2",
    platforms: [
        .iOS(.v17),  // HummingBird v2.x requires iOS 17+
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTTPServerAdaptersV2",
            targets: ["HTTPServerAdaptersV2"]
        ),
    ],
    dependencies: [
        // Core shared interfaces
        .package(path: "../HTTPServerAdaptersCore"),
        // HummingBird v2.x for HTTP server functionality
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdaptersV2",
            dependencies: [
                .product(name: "HTTPServerAdaptersCore", package: "HTTPServerAdaptersCore"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersV2Tests",
            dependencies: ["HTTPServerAdaptersV2"]
        ),
    ]
)