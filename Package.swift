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
        .package(url: "https://github.com/media-net/medianetadsdk-dist", from: "1.0.2"),
        .package(url: "https://github.com/media-net/ios-packages", from: "1.0.4"),
    ],
    targets: [
        .binaryTarget(
            name: "BytesSDK",
            url: "https://github.com/media-net/bytes-packages/releases/download/v1.0.2/BytesSDK-1.0.2.xcframework.zip",
            checksum: "a1adec7358802502b3b26f117a339c5abc500307bd5893af3a2519b4ce6b2c28"
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
