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
    ],
    targets: [
        .binaryTarget(
            name: "BytesSDK",
            url: "https://github.com/media-net/bytes-packages/releases/download/v0.1.0/BytesSDK-0.1.0.xcframework.zip",
            checksum: "e39ddb8c5c1db3bcb7a630c45d704129773d6362ebac2c24365953ed3e57675d"
        ),
    ]
)
