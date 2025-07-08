// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPServerAdapters",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
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
        // FlyingFox for HTTP server functionality
        .package(url: "https://github.com/swhitty/FlyingFox", from: "0.24.0"),
        // HummingBird v1.x for iOS 15+ TLS support
        .package(url: "https://github.com/hummingbird-project/hummingbird", exact: "1.12.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdapters",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "FlyingFox", package: "FlyingFox"),
                .product(name: "Hummingbird", package: "hummingbird", condition: .when(platforms: [.iOS])),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersTests",
            dependencies: ["HTTPServerAdapters"]
        ),
    ]
)