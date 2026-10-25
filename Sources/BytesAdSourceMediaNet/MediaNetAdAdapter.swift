import UIKit
import os
@_spi(BytesAdapter) import BytesSDK
import MediaNetAdSDK
import MediaNetRendererAdSDK
import GoogleMobileAds

/// ``BytesAdAdapter`` backed by the Media.net iOS Ad SDK (`MediaNetAdSDK`).
///
/// The host wires this once at app startup:
/// ```swift
/// Bytes.setAdAdapter(
///     MediaNetAdAdapter(
///         accountID: "8CU...",
///         bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
///         card: MediaNetPlacementConfig(configID: "YOUR_STORED_IMP_ID", adUnitID: "/1234/card"),
///         bottom: MediaNetPlacementConfig(configID: "YOUR_STORED_IMP_ID", adUnitID: "/1234/bottom")
///     )
/// )
/// ```
/// The Media.net SDK is initialized once, lazily, on first load.
///
/// `BannerAdView` is a `UIView`, so its constructor, `loadAd()`, and
/// `destroy` all require the main thread. Internal callbacks (wrapper
/// init listener, Prebid listener) may arrive on background threads;
/// the adapter marshals them onto the main thread before touching the
/// banner.
/// Per-placement Media.net config the host provides at init: the Prebid
/// stored-impression config ID and the GAM ad unit path. The requested ad
/// sizes are owned by the adapter (see ``MediaNetAdAdapter/cardSizes`` /
/// ``MediaNetAdAdapter/bottomSizes``), not the host.
public struct MediaNetPlacementConfig {
    public let configID: String
    public let adUnitID: String

    public init(configID: String, adUnitID: String) {
        self.configID = configID
        self.adUnitID = adUnitID
    }
}

public final class MediaNetAdAdapter: BytesAdAdapter {

    private let accountID: String
    private let bundleIdentifier: String
    private let cardConfig: MediaNetPlacementConfig
    private let bottomConfig: MediaNetPlacementConfig
    private let initializer: MediaNetSdkInitializer
    private let bannerFactory: BannerFactory

    /// Sends the `mnet_renderer_not_ready` beacon. Main thread only (called from
    /// `continueLoad`). Swapped in tests.
    static var reportRendererNotReady: (BytesAdPlacement) -> Void = { placement in
        MainActor.assumeIsolated { Bytes.logAdRendererNotReady(placement: placement) }
    }

    /// Public constructor. The adapter owns the per-placement Prebid config
    /// ID, GAM ad unit, and sizes; the SDK only passes a ``BytesAdPlacement``.
    ///
    /// - Parameters:
    ///   - accountID: Media.net account ID.
    ///   - bundleIdentifier: the host app bundle identifier. Defaults to
    ///     `Bundle.main.bundleIdentifier`.
    ///   - card: config for the in-feed card slot.
    ///   - bottom: config for the bottom banner. Falls back to `card` when
    ///     omitted.
    public convenience init(
        accountID: String,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        card: MediaNetPlacementConfig,
        bottom: MediaNetPlacementConfig? = nil
    ) {
        self.init(
            accountID: accountID,
            bundleIdentifier: bundleIdentifier ?? "",
            card: card,
            bottom: bottom ?? card,
            initializer: MediaNetSdkInitializers.default,
            bannerFactory: DefaultBannerFactory()
        )
    }

    /// Internal constructor for tests. Inject a fake initializer + banner
    /// factory to drive the adapter without the real wrapper.
    internal init(
        accountID: String,
        bundleIdentifier: String,
        card: MediaNetPlacementConfig,
        bottom: MediaNetPlacementConfig,
        initializer: MediaNetSdkInitializer,
        bannerFactory: BannerFactory
    ) {
        self.accountID = accountID
        self.bundleIdentifier = bundleIdentifier
        self.cardConfig = card
        self.bottomConfig = bottom
        self.initializer = initializer
        self.bannerFactory = bannerFactory
    }

    /// Standardized in-feed card sizes (multiformat). 300×600 is primary; the
    /// rest are requested as additional sizes in a single auction.
    public static let cardSizes: [BytesAdSize] = [
        BytesAdSize(width: 300, height: 600),
        .mrec,                                   // 300×250
        BytesAdSize(width: 320, height: 480),
    ]

    /// Standardized docked bottom-banner sizes. 320×100 is primary.
    public static let bottomSizes: [BytesAdSize] = [
        BytesAdSize(width: 320, height: 100),
        .banner,                                 // 320×50
        BytesAdSize(width: 300, height: 50),
    ]

    /// Prebid account ID, sent on the OTA request as `pbsdk_account_id` so the server can fill `adt1`. Empty when blank.
    public var otaRequestParams: [String: String] {
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [:] : [BytesOTARequestParam.pbsdkAccountID: trimmed]
    }

    // BytesAdPlacement is not @frozen and this file ships as source, so each
    // switch needs @unknown default or the host app's build warns (an error in
    // the Swift 6 language mode). A placement this adapter doesn't know yet
    // falls back to the card setup.
    private func config(for placement: BytesAdPlacement) -> MediaNetPlacementConfig {
        switch placement {
        case .card: return cardConfig
        case .bottom: return bottomConfig
        @unknown default: return cardConfig
        }
    }

    private static func sizes(for placement: BytesAdPlacement) -> [BytesAdSize] {
        switch placement {
        case .card: return cardSizes
        case .bottom: return bottomSizes
        @unknown default: return cardSizes
        }
    }

    private static func formats(for placement: BytesAdPlacement) -> AdMediaFormat {
        switch placement {
        case .card: return [.banner, .video]
        case .bottom: return .banner
        @unknown default: return [.banner, .video]
        }
    }

    private static func formatsDescription(_ formats: AdMediaFormat) -> String {
        var parts: [String] = []
        if formats.contains(.banner) { parts.append("banner") }
        if formats.contains(.video) { parts.append("video") }
        if formats.contains(.native) { parts.append("native") }
        return parts.joined(separator: "+")
    }

    public func requestedAdSizes(for placement: BytesAdPlacement) -> [BytesAdSize] {
        Self.sizes(for: placement)
    }

    public func maxAdSize(for placement: BytesAdPlacement) -> BytesAdSize? {
        Self.sizes(for: placement).max { $0.height < $1.height }
    }

    /// `<MediaNetAdSDK version>__<renderer version>`, for example `1.0.2__1.0.4`.
    public var codeVersion: String? { Self.cachedCodeVersion }

    /// Built once: both SDK versions are fixed for the life of the process.
    // The renderer part is not a dedicated release version: it is the value
    // Prebid matches against `bid.pluginRendererVersion`. It only tracks the
    // renderer release since renderer 98dea2f (it was stuck at 1.0.0 before),
    // so if the two diverge again, svr reports the wrong renderer version.
    private static let cachedCodeVersion =
        "\(MediaNetAdSDKClient.shared.sdkVersion)__\(MNRPluginRenderer.shared.version)"

    static func maxSize(for placement: BytesAdPlacement) -> BytesAdSize? {
        let sizes = sizes(for: placement)
        guard let maxWidth = sizes.map(\.width).max(), let maxHeight = sizes.map(\.height).max() else {
            return nil
        }
        return BytesAdSize(width: maxWidth, height: maxHeight)
    }

    /// Starts the Media.net wrapper init (and the renderer plugin's
    /// registration) at Bytes SDK init, so the plugin is usually registered —
    /// and advertised in the auction request — by the time the first ad is
    /// due. Does not delay auctions: `loadBanner` still waits only for the
    /// wrapper's `configure`, as before.
    public func prepare() {
        log.notice("prepare — warming up Media.net SDK")
        initializer.ensureInitialized(
            accountID: accountID,
            bundleIdentifier: bundleIdentifier
        ) { initOk in
            log.notice("prepare — Media.net SDK init \(initOk ? "ok" : "FAILED", privacy: .public)")
        }
    }

    public func loadBanner(
        placement: BytesAdPlacement,
        callback: BytesAdAdapterCallback
    ) -> BytesBannerAdHandle {
        // BannerAdView is a UIView — constructed on main per the wrapper
        // doc. BytesBannerAd marshals `loadBanner` to main before this
        // runs, so we are on main here.
        let config = config(for: placement)
        let sizes = Self.sizes(for: placement)
        let cgSize = CGSize(width: sizes[0].width, height: sizes[0].height)
        let additionalCGSizes = sizes.dropFirst().map {
            CGSize(width: $0.width, height: $0.height)
        }
        let allSizes = sizes
            .map(\.dimensionString)
            .joined(separator: ",")
        let formats = Self.formats(for: placement)
        log.notice("loadBanner placement=\(String(describing: placement), privacy: .public) adUnit=\(config.adUnitID, privacy: .public) configID=\(config.configID, privacy: .public) sizes=\(allSizes, privacy: .public) formats=\(Self.formatsDescription(formats), privacy: .public)")
        let banner = bannerFactory.create(
            configID: config.configID,
            adUnitID: config.adUnitID,
            adSize: cgSize,
            additionalSizes: additionalCGSizes,
            formats: formats
        )
        let handle = MediaNetBannerHandle(banner: banner)

        // Prebid's creative factory runs JS inside a WKWebView. If that
        // WKWebView has no window it times out. Park the view off-screen in
        // the key window now; the caller re-parents it via addSubview on
        // onAdLoaded, which removes it from here automatically.
        attachOffscreen(banner.asView())

        initializer.ensureInitialized(
            accountID: accountID,
            bundleIdentifier: bundleIdentifier
        ) { [weak self, weak handle] initOk in
            guard let self, let handle else { return }
            // Hop to main: the wrapper's init listener may fire on any
            // thread, and BannerAdView ops must be on main.
            DispatchQueue.main.async {
                self.continueLoad(
                    initOk: initOk,
                    banner: banner,
                    handle: handle,
                    placement: placement,
                    callback: callback
                )
            }
        }

        return handle
    }

    private func attachOffscreen(_ view: UIView) {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window = keyWindow else { return }
        view.frame.origin = CGPoint(x: 0, y: window.bounds.height * 2)
        view.alpha = Self.offscreenLoadAlpha
        view.isUserInteractionEnabled = false
        window.insertSubview(view, at: 0)
    }

    private static let offscreenLoadAlpha: CGFloat = 0.02

    private func continueLoad(
        initOk: Bool,
        banner: MediaNetBanner,
        handle: MediaNetBannerHandle,
        placement: BytesAdPlacement,
        callback: BytesAdAdapterCallback
    ) {
        guard !handle.isDestroyed else {
            log.notice("continueLoad skipped — handle destroyed during init")
            return
        }

        log.notice("Media.net SDK init \(initOk ? "ok — starting auction" : "FAILED", privacy: .public)")
        if !initOk {
            banner.asView().removeFromSuperview()
            callback.onAdLoadFailed(
                BytesAdError(
                    code: BytesAdError.codeSdkNotInitialized,
                    message: "Media.net SDK init failed"
                )
            )
            handle.destroy()
            return
        }

        let prebidListener = MediaNetBannerListener(
            banner: banner,
            handle: handle,
            placement: placement,
            callback: callback
        )
        banner.setListener(prebidListener)
        handle.retainListener(prebidListener)
        banner.disableAutoRefresh()
        if !DefaultMediaNetSdkInitRunner.rendererAnswered {
            log.notice("MNRPluginRenderer not registered yet — starting auction without it")
            Self.reportRendererNotReady(placement)
        }
        banner.loadAd()
    }
}

// MARK: - Handle

internal final class MediaNetBannerHandle: BytesBannerAdHandle {
    private let banner: MediaNetBanner
    private let lock = NSLock()
    private var _destroyed: Bool = false
    private var retainedListener: AnyObject?

    init(banner: MediaNetBanner) {
        self.banner = banner
    }

    var isDestroyed: Bool {
        lock.lock(); defer { lock.unlock() }
        return _destroyed
    }

    func destroy() {
        lock.lock()
        guard !_destroyed else { lock.unlock(); return }
        _destroyed = true
        retainedListener = nil
        lock.unlock()
        // Tear down on main: removing the view and destroying the banner both
        // touch UIKit. `removeFromSuperview()` pulls the banner out of the
        // key window if it is still parked offscreen — when the host destroys
        // during the auction (user swipes away before onAdLoaded re-parents
        // the view), nothing else removes it and it would leak in the window.
        // `MediaNetBanner.destroy()` is a no-op on iOS — the wrapper's
        // `BannerAdView` releases its internal Prebid resources in its own
        // deinit; the call is kept for symmetry and future adapters.
        let teardown = { [banner] in
            banner.asView().removeFromSuperview()
            banner.destroy()
        }
        if Thread.isMainThread {
            teardown()
        } else {
            DispatchQueue.main.async(execute: teardown)
        }
    }

    /// Holds a strong ref on the Prebid listener so it stays alive for
    /// the load's lifetime even though the banner only retains it weakly.
    func retainListener(_ listener: AnyObject) {
        lock.lock(); defer { lock.unlock() }
        guard !_destroyed else { return }
        retainedListener = listener
    }
}

// MARK: - Prebid listener bridge

/// Translates Prebid `BannerView` delegate calls into
/// ``BytesAdAdapterCallback``. Enforces the BytesAdAdapterCallback
/// cardinality contract (load is exactly one terminal; impression at
/// most one).
internal final class MediaNetBannerListener: NSObject {
    private let bannerRef: () -> MediaNetBanner?
    private weak var handle: MediaNetBannerHandle?
    private let placement: BytesAdPlacement
    private let callback: BytesAdAdapterCallback

    /// Pending → Loaded XOR Pending → Failed (atomic).
    private let phaseLock = NSLock()
    private var phase: LoadPhase = .pending
    private var impressionFired = false

    init(
        banner: MediaNetBanner,
        handle: MediaNetBannerHandle,
        placement: BytesAdPlacement,
        callback: BytesAdAdapterCallback
    ) {
        // The bridge holds a strong ref to the underlying banner via the
        // closure so it can return `banner.asView()` to the host listener
        // without retaining the high-level handle wrapper.
        self.bannerRef = { banner }
        self.handle = handle
        self.placement = placement
        self.callback = callback
    }

    func onAdLoaded(creativeSize: CGSize? = nil) {
        log.notice("banner onAdLoaded")
        guard let handle, !handle.isDestroyed else { return }
        phaseLock.lock()
        let isPending = phase == .pending
        phaseLock.unlock()
        guard isPending else { return }
        if let rejection = oversizeRejectionMessage(creativeSize: creativeSize) {
            onAdFailed(message: rejection)
            return
        }
        if transitionTo(.loaded) {
            if let view = bannerRef()?.asView() {
                view.alpha = 1
                view.isUserInteractionEnabled = true
                callback.onAdLoaded(view, metadata: Self.metadata(creativeSize: creativeSize))
            }
        }
    }

    private func oversizeRejectionMessage(creativeSize: CGSize?) -> String? {
        guard case .bottom = placement else { return nil }
        guard let creativeSize, creativeSize.width > 0, creativeSize.height > 0 else {
            return "creative size unknown for bottom placement"
        }
        guard let maxSize = MediaNetAdAdapter.maxSize(for: placement) else {
            return nil
        }
        guard creativeSize.width > CGFloat(maxSize.width) || creativeSize.height > CGFloat(maxSize.height) else {
            return nil
        }
        return "creative \(Int(creativeSize.width))x\(Int(creativeSize.height)) exceeds \(placement) max \(maxSize.width)x\(maxSize.height)"
    }

    private static func metadata(creativeSize: CGSize?) -> BytesAdMetadata {
        guard let creativeSize, creativeSize.width > 0, creativeSize.height > 0 else {
            return BytesAdMetadata(size: nil, type: .banner)
        }
        return BytesAdMetadata(
            size: BytesAdSize(width: Int(creativeSize.width), height: Int(creativeSize.height)),
            type: .banner
        )
    }

    func onAdFailed(message: String?) {
        log.notice("banner onAdFailed: \(message ?? "no fill", privacy: .public)")
        guard let handle, !handle.isDestroyed else { return }
        if transitionTo(.failed) {
            bannerRef()?.asView().removeFromSuperview()
            callback.onAdLoadFailed(
                BytesAdError(
                    code: BytesAdError.codeNoFill,
                    message: message ?? "no fill"
                )
            )
            handle.destroy()
        }
    }

    func onAdDisplayed() {
        guard let handle, !handle.isDestroyed else { return }
        phaseLock.lock()
        let canFire = phase == .loaded && !impressionFired
        if canFire { impressionFired = true }
        phaseLock.unlock()
        if canFire { callback.onAdImpression() }
    }

    func onAdClicked() {
        guard let handle, !handle.isDestroyed else { return }
        phaseLock.lock()
        let canFire = phase == .loaded
        phaseLock.unlock()
        if canFire { callback.onAdClicked() }
    }

    func onClickthroughOpened() {
        guard let handle, !handle.isDestroyed else { return }
        phaseLock.lock()
        let canFire = phase == .loaded
        phaseLock.unlock()
        if canFire { callback.onAdClickthroughOpened() }
    }

    func onClickthroughClosed() {
        guard let handle, !handle.isDestroyed else { return }
        phaseLock.lock()
        let canFire = phase == .loaded
        phaseLock.unlock()
        if canFire { callback.onAdClickthroughClosed() }
    }

    private func transitionTo(_ next: LoadPhase) -> Bool {
        phaseLock.lock(); defer { phaseLock.unlock() }
        guard phase == .pending else { return false }
        phase = next
        return true
    }

    private enum LoadPhase {
        case pending, loaded, failed
    }
}

// MARK: - Banner abstraction

/// Thin protocol over Media.net's `BannerAdView` so the adapter's banner
/// lifecycle (setListener / loadAd / destroy / asView) can be faked in
/// tests. Production uses ``DefaultBannerFactory`` which wraps the real
/// wrapper class.
internal protocol BannerFactory {
    func create(
        configID: String,
        adUnitID: String,
        adSize: CGSize,
        additionalSizes: [CGSize],
        formats: AdMediaFormat
    ) -> MediaNetBanner
}

internal protocol MediaNetBanner: AnyObject {
    func setListener(_ listener: MediaNetBannerListener)
    func disableAutoRefresh()
    func loadAd()
    func destroy()
    func asView() -> UIView
}

internal final class DefaultBannerFactory: BannerFactory {
    func create(
        configID: String,
        adUnitID: String,
        adSize: CGSize,
        additionalSizes: [CGSize],
        formats: AdMediaFormat
    ) -> MediaNetBanner {
        let validGADAdSizes = ([adSize] + additionalSizes).map {
            nsValue(for: adSizeFor(cgSize: $0))
        }
        let eventHandler = GAMBannerAdEventHandler(
            adUnitID: adUnitID,
            validGADAdSizes: validGADAdSizes
        )
        let banner = BannerAdView(
            frame: CGRect(origin: .zero, size: adSize),
            configID: configID,
            adSize: adSize,
            eventHandler: eventHandler
        )
        banner.additionalSizes = additionalSizes.isEmpty ? nil : additionalSizes
        banner.adFormat = formats
        return RealMediaNetBanner(banner: banner)
    }
}

internal final class RealMediaNetBanner: NSObject, MediaNetBanner, BannerAdViewDelegate {
    private let banner: BannerAdView
    private weak var listener: MediaNetBannerListener?

    init(banner: BannerAdView) {
        self.banner = banner
        super.init()
        banner.delegate = self
    }

    func setListener(_ listener: MediaNetBannerListener) {
        self.listener = listener
    }

    func disableAutoRefresh() {
        // Use a negative value, not 0, to turn refresh off. The wrapper clamps
        // `refreshInterval` to its 15s minimum for any non-negative value below
        // it, so `= 0` silently becomes 15s and the banner keeps refreshing. A
        // negative value is the disable sentinel: it is stored as 0 (verified at
        // runtime — readback is 0) and no refresh timer arms.
        banner.refreshInterval = -1
        banner.stopRefresh()
    }

    func loadAd() {
        banner.loadAd()
        pinContentsToFill()
    }

    /// Ahmed's fix, applied here at the adapter level (his "defensive right after
    /// `loadAd()`"). The wrapper's `BannerAdView` pins its inner banner to its edges
    /// but leaves `translatesAutoresizingMaskIntoConstraints = true`, so UIKit's
    /// autoresizing constraints override the pins and a GAM / default-renderer
    /// creative renders in the top-left corner (or zero-sized). Turn autoresizing off
    /// and pin every content subview to fill, so the creative fills the `BannerAdView`;
    /// the feed cell then scales and centers the whole view.
    private func pinContentsToFill() {
        for content in banner.subviews {
            content.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: banner.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: banner.trailingAnchor),
                content.topAnchor.constraint(equalTo: banner.topAnchor),
                content.bottomAnchor.constraint(equalTo: banner.bottomAnchor),
            ])
        }
    }

    /// `BannerAdView` cleans up in its own `deinit`. Dropping the strong
    /// reference is the destroy. The handle keeps no strong ref after this.
    func destroy() {
        // No-op: ARC handles teardown when the handle releases the banner.
    }

    func asView() -> UIView { banner }

    // MARK: BannerAdViewDelegate

    func bannerViewPresentationController() -> UIViewController? {
        // GAMBannerView needs a non-nil rootViewController to render its creative.
        // Walk the key window to find the topmost presented controller.
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var vc = keyWindow?.rootViewController
        while let presented = vc?.presentedViewController {
            vc = presented
        }
        return vc
    }

    func bannerView(_ view: BannerAdView, didReceiveAdWithAdSize adSize: CGSize) {
        banner.stopRefresh()
        if adSize.width > 0, adSize.height > 0 {
            view.frame.size = adSize
        }
        listener?.onAdLoaded(creativeSize: adSize)
    }

    func bannerView(_ view: BannerAdView, didFailToReceiveAdWith error: Error) {
        listener?.onAdFailed(message: error.localizedDescription)
    }

    func bannerViewWillPresentModal(_ view: BannerAdView) {
        listener?.onAdClicked()
        listener?.onClickthroughOpened()
    }

    func bannerViewDidDismissModal(_ view: BannerAdView) {
        listener?.onClickthroughClosed()
    }

    func bannerViewWillLeaveApplication(_ view: BannerAdView) {
        listener?.onAdClicked()
    }
}

private let log = Logger(subsystem: "net.media.bytessdk.adsource.medianet", category: "MediaNetAdAdapter")
