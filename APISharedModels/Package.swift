// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "APISharedModels",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "APISharedModels",
            targets: ["APISharedModels"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "APISharedModels",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "APISharedModelsTests",
            dependencies: ["APISharedModels"]
        )
    ]
)
