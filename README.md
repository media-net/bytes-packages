# BytesSDK — iOS distribution

Public distribution wrapper for the Media.net **BytesSDK** (vertical-video SDK,
iOS 14+). This repo carries only the SPM/CocoaPods manifests; each release tag
`vX.Y.Z` references a prebuilt, unsigned `BytesSDK.xcframework` attached to
that release. Sources are maintained privately in `media-net/bytes-sdk-ios`.

Current release: **0.1.0**

## Swift Package Manager

```swift
.package(url: "https://github.com/media-net/bytes-packages.git", from: "0.1.0")
```

Then add `BytesSDK` to your target's dependencies.

## CocoaPods

```ruby
pod 'BytesSDK', :podspec => 'https://raw.githubusercontent.com/media-net/bytes-packages/v0.1.0/BytesSDK.podspec'
```

## Manual

Download `BytesSDK-0.1.0.xcframework.zip` from the
[release assets](https://github.com/media-net/bytes-packages/releases/tag/v0.1.0)
and drag `BytesSDK.xcframework` into your target (Embed & Sign).
