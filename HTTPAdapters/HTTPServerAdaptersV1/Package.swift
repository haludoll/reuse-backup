// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPServerAdaptersV1",
    platforms: [
        .iOS(.v15),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTTPServerAdaptersV1",
            targets: ["HTTPServerAdaptersV1"]
        ),
    ],
    dependencies: [
        // Core shared interfaces
        .package(path: "../HTTPServerAdaptersCore"),
        // HummingBird v1.x for HTTP server functionality
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdaptersV1",
            dependencies: [
                .product(name: "HTTPServerAdaptersCore", package: "HTTPServerAdaptersCore"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
    ]
)