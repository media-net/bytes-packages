# BytesSDK for iOS

Media.net **BytesSDK** adds a full-screen, vertical-video (shorts-style) feed to
an iOS app. Current release: **1.0.2**.

Two products ship from this repo:

- **`BytesSDK`**: the feed, a prebuilt `BytesSDK.xcframework` attached to each
  `vX.Y.Z` release.
- **`BytesAdSourceMediaNet`**: the Media.net ad source, shipped as source. It
  links the Media.net Ad SDK (`media-net/medianetadsdk-dist` 1.0.2+), the Media.net
  renderer (`media-net/ios-packages` 1.0.4+) and Google Mobile Ads. Add it
  to show Media.net ads in the feed.

## Requirements

- iOS 15.0 or later.
- Xcode 26.6 or later. The binary's Swift interface is built with Swift 6.3.3,
  and older compilers cannot import it.

## Install with Swift Package Manager

In Xcode, choose File > Add Package Dependencies and enter the repo URL, or add
it to `Package.swift`:

```swift
.package(url: "https://github.com/media-net/bytes-packages.git", from: "1.0.2")
```

Add both `BytesSDK` and `BytesAdSourceMediaNet` to your app target. The Media.net
and Google packages resolve automatically.

## Install with CocoaPods

BytesSDK and BytesAdSourceMediaNet are on the CocoaPods trunk, and so are the Media.net pods they depend on. The Media.net frameworks are static, so use static linkage.

```ruby
platform :ios, '15.0'
use_frameworks! :linkage => :static

target 'YourApp' do
  pod 'BytesSDK', '1.0.2'
  pod 'BytesAdSourceMediaNet', '1.0.2'
end

# Xcode 27 rejects deployment targets below iOS 15. Some of these pods declare
# an older minimum, so raise them or the Pods project fails to build.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end
```

If `pod install` reports that it cannot find a compatible version of a Media.net
pod, your local copy of the CocoaPods index predates that release. Run
`pod install --repo-update` once.

## Configure your app

These settings belong to your app target. The SDK cannot add them for you.

| Setting | Required | Why |
|---|---|---|
| `GADApplicationIdentifier` in Info.plist | Yes | Google Mobile Ads stops the app at launch without it. Use your app's Google Mobile Ads app ID. |
| `-ObjC` in Other Linker Flags | Yes | Google Mobile Ads fails to initialize without it. |
| `SKAdNetworkItems` in Info.plist | Recommended | Install attribution for Google and Media.net demand partners. Ask your Media.net contact for the list. |
| `NSUserTrackingUsageDescription` and an App Tracking Transparency prompt | Optional | BytesSDK never reads the IDFA. Google and Media.net use it only if the user allows tracking. |

## Quick start

Initialize once per launch, on the main thread, after your window scene is
connected (for example in `scene(_:willConnectTo:options:)`). Media.net
provides every ID below.

```swift
import BytesSDK
import BytesAdSourceMediaNet

Bytes.initialize(
    cid: "<cid>",
    crid: "<crid>",
    appBundleId: Bundle.main.bundleIdentifier ?? "",
    containerView: nil
)

Bytes.setAdAdapter(
    MediaNetAdAdapter(
        accountID: "<Media.net account ID>",
        card: MediaNetPlacementConfig(configID: "<card config ID>", adUnitID: "<card ad unit path>"),
        bottom: MediaNetPlacementConfig(configID: "<bottom config ID>", adUnitID: "<bottom ad unit path>")
    )
)
```

Open the feed from any view controller, or add the ready-made button that opens
it on tap:

```swift
Bytes.presentFeed(from: self)

let button = Bytes.feedButton()
view.addSubview(button)
```

To follow the feed's lifecycle, register a `BytesEventListener` with
`Bytes.addEventListener(_:)`. It receives `sdkInitialized`,
`sdkInitializedFailed`, `feedExpanded`, `feedCollapsed`, `adStarted`,
`adCompleted` and `adSkipped` on the main thread. Errors also arrive on
`Bytes.errors()`, an `AsyncStream`.

## App privacy

`BytesSDK.framework` includes a `PrivacyInfo.xcprivacy`. It declares no
tracking and no tracking domains, and these collected data types:

| Data type | Linked to the user | Purpose |
|---|---|---|
| Device ID (a server-assigned visitor ID) | Yes | Analytics, app functionality |
| Product interaction | No | Analytics |
| Advertising data | No | Third-party and developer advertising |
| Crash data | No | App functionality |
| Other diagnostic data | No | App functionality |

Google Mobile Ads and the Media.net frameworks ship their own manifests. To
fill in the App Privacy section in App Store Connect, archive your app and use
Xcode's Generate Privacy Report, which combines all of them.

## Signature

`BytesSDK.xcframework` is signed by **Apple Distribution: Adley Dsouza
(53J4RH54RJ)**, the same signer as the Media.net Ad SDK and renderer. Xcode
shows it in the framework's Signature inspector and warns if a later version
is signed by someone else. Xcode re-signs the framework with your identity when
it embeds it.

## Manual install

Download `BytesSDK-1.0.2.xcframework.zip` from the
[release assets](https://github.com/media-net/bytes-packages/releases/tag/v1.0.2),
unzip it, and drag `BytesSDK.xcframework` into your target with Embed & Sign.
`BytesSDK-1.0.2.dSYMs.zip` holds the debug symbols for crash reports.
Media.net ads still need the ad source and its dependencies, so prefer Swift
Package Manager or CocoaPods.
