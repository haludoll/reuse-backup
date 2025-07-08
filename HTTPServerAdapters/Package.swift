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
        // HummingBird for HTTP server functionality
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.0.0"),
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