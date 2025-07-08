// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HTTPServerAdaptersCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTTPServerAdaptersCore",
            targets: ["HTTPServerAdaptersCore"]
        ),
    ],
    dependencies: [
        // Apple's standardized HTTP types
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "HTTPServerAdaptersCore",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .testTarget(
            name: "HTTPServerAdaptersCoreTests",
            dependencies: ["HTTPServerAdaptersCore"]
        ),
    ]
)