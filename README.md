# BytesSDK — iOS distribution

Public distribution wrapper for the Media.net **BytesSDK** (vertical-video SDK,
iOS 14+). Two products ship from here:

- **`BytesSDK`** — the core feed, a prebuilt unsigned `BytesSDK.xcframework`
  attached to each `vX.Y.Z` release.
- **`BytesAdSourceMediaNet`** — the Media.net ad source (thin glue), vended as
  source; it links the Media.net Ad SDK from `media-net/ios-packages`.

Core sources are maintained privately in `media-net/bytes-sdk-ios`.

Current release: **1.0.0**

## Swift Package Manager

```swift
.package(url: "https://github.com/media-net/bytes-packages.git", from: "1.0.0")
```

Add `BytesSDK` to your target; add `BytesAdSourceMediaNet` too if you render
Media.net demand (it pulls `ios-packages` transitively).

## CocoaPods

```ruby
pod 'BytesSDK', :podspec => 'https://raw.githubusercontent.com/media-net/bytes-packages/v1.0.0/BytesSDK.podspec'
```

If you render Media.net demand, add the ad source. None of the Media.net pods
are published to the CocoaPods trunk, so every podspec is referenced by URL —
CocoaPods does not resolve external-source dependencies transitively:

```ruby
pod 'BytesAdSourceMediaNet', :podspec => 'https://raw.githubusercontent.com/media-net/bytes-packages/v1.0.0/BytesAdSourceMediaNet.podspec'
pod 'MediaNetAdSDK', :podspec => 'https://raw.githubusercontent.com/media-net/ios-packages/main/MediaNetAdSDK.podspec'
pod 'MediaNetRendererAdSDK', :podspec => 'https://raw.githubusercontent.com/media-net/ios-packages/main/MediaNetRendererAdSDK.podspec'
pod 'MediaNetRendererCore', :podspec => 'https://raw.githubusercontent.com/media-net/ios-packages/main/MediaNetRendererCore.podspec'
pod 'MNPrebidMobile', :podspec => 'https://raw.githubusercontent.com/media-net/ios-packages/main/MNPrebidMobile.podspec'
pod 'OMSDK_Medianet', :podspec => 'https://raw.githubusercontent.com/media-net/ios-packages/main/OMSDK_Medianet.podspec'
```

## Manual

Download `BytesSDK-1.0.0.xcframework.zip` from the
[release assets](https://github.com/media-net/bytes-packages/releases/tag/v1.0.0)
and drag `BytesSDK.xcframework` into your target (Embed & Sign).
