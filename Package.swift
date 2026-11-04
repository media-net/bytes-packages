// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BytesSDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "BytesSDK",
            targets: ["BytesSDK"]
        ),
        .library(
            name: "BytesAdSourceMediaNet",
            targets: ["BytesAdSourceMediaNet"]
        ),
    ],
    dependencies: [
        // The ad source links the Media.net Ad SDK (and GoogleMobileAds
        // transitively) plus the Media.net renderer. Generated from
        // bytes-sdk-ios/Package.swift — do not edit by hand.
        .package(url: "https://github.com/media-net/medianetadsdk-dist", from: "1.1.0"),
        .package(url: "https://github.com/media-net/ios-packages", from: "1.1.0"),
    ],
    targets: [
        .binaryTarget(
            name: "BytesSDK",
            url: "https://github.com/media-net/bytes-packages/releases/download/v1.1.0/BytesSDK-1.1.0.xcframework.zip",
            checksum: "d820ebad48762f2d9fe3df3733e45a170e6d152ab44938e88b89e0bf2c070de4"
        ),
        // Media.net ad source — thin glue shipped as source. Mirrors the
        // adapter target in bytes-sdk-ios: depends on the core binary plus the
        // Media.net products it links (a binaryTarget cannot carry those).
        .target(
            name: "BytesAdSourceMediaNet",
            dependencies: [
                "BytesSDK",
                .product(name: "MediaNetAdSDK", package: "medianetadsdk-dist"),
                .product(name: "MediaNetRendererAdSDK", package: "ios-packages"),
            ],
            path: "Sources/BytesAdSourceMediaNet"
        ),
    ]
)
