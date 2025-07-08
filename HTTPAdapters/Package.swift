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
        // Apple's standardized HTTP types
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        // HummingBird v1.x for HTTP server functionality (iOS 15+ compatible)
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdapters",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersTests",
            dependencies: ["HTTPServerAdapters"]
        ),
    ]
)