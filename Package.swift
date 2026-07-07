// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BytesSDK",
    platforms: [
        .iOS(.v14),
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
        // transitively). Kept in sync with bytes-sdk-ios/Package.swift.
        .package(url: "https://github.com/media-net/ios-packages", from: "0.4.6"),
    ],
    targets: [
        .binaryTarget(
            name: "BytesSDK",
            url: "https://github.com/media-net/bytes-packages/releases/download/v1.0.0/BytesSDK-1.0.0.xcframework.zip",
            checksum: "d2e64305c102cc4bea5732580c6ff777382156de3c8b39e46bba681b12b3b92f"
        ),
        // Media.net ad source — thin glue shipped as source. Mirrors the
        // adapter target in bytes-sdk-ios: depends on the core binary plus the
        // ios-packages products it links (a binaryTarget cannot carry those).
        .target(
            name: "BytesAdSourceMediaNet",
            dependencies: [
                "BytesSDK",
                .product(name: "MediaNetAdSDK", package: "ios-packages"),
                .product(name: "MediaNetRendererAdSDK", package: "ios-packages"),
            ],
            path: "Sources/BytesAdSourceMediaNet"
        ),
    ]
)
