# BytesSDK — iOS distribution

Public distribution wrapper for the Media.net **BytesSDK** (vertical-video SDK,
iOS 14+). Two products ship from here:

- **`BytesSDK`** — the core feed, a prebuilt unsigned `BytesSDK.xcframework`
  attached to each `vX.Y.Z` release.
- **`BytesAdSourceMediaNet`** — the Media.net ad source (thin glue), vended as
  source; it links the Media.net Ad SDK from `media-net/ios-packages`.

Core sources are maintained privately in `media-net/bytes-sdk-ios`.

Current release: **0.2.0**

## Swift Package Manager

```swift
.package(url: "https://github.com/media-net/bytes-packages.git", from: "0.2.0")
```

Add `BytesSDK` to your target; add `BytesAdSourceMediaNet` too if you render
Media.net demand (it pulls `ios-packages` transitively).

## CocoaPods

```ruby
pod 'BytesSDK', :podspec => 'https://raw.githubusercontent.com/media-net/bytes-packages/v0.2.0/BytesSDK.podspec'
```

## Manual

Download `BytesSDK-0.2.0.xcframework.zip` from the
[release assets](https://github.com/media-net/bytes-packages/releases/tag/v0.2.0)
and drag `BytesSDK.xcframework` into your target (Embed & Sign).
