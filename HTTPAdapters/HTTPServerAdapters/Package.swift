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
        // HummingBird v2.x for iOS 17+ (conditionally imported)
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdapters",
            dependencies: [
                .product(name: "HTTPServerAdaptersCore", package: "HTTPServerAdaptersCore"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersTests",
            dependencies: ["HTTPServerAdapters"]
        ),
    ]
)