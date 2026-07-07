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
            url: "https://github.com/media-net/bytes-packages/releases/download/v0.2.0/BytesSDK-0.2.0.xcframework.zip",
            checksum: "a05328ebd03bf7e67d589ff78815f7798300ccc961956eeea93884d4e94dc9b3"
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
