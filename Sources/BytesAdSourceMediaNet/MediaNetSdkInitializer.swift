import Foundation
import os
import MediaNetAdSDK
import MediaNetRendererAdSDK
import GoogleMobileAds

/// Wraps Media.net's `MediaNetAdSDKClient.shared.configure(...)` call (plus
/// GMA's `MobileAds.shared.start()`) so it can be mocked in unit tests.
/// Production uses ``Default``, a process-wide singleton that coalesces
/// concurrent init requests and runs the real init at most once per
/// process. Tests inject a fake.
///
/// `then` is invoked with `true` on success, `false` on failure. Once a
/// terminal result is known (success or failure), all future
/// `ensureInitialized` calls fire `then` with that result immediately.
/// The wrapper init is never retried — a failed init is treated as a
/// terminal config error; the host has to fix it (new accountID, new
/// Info.plist) and restart the process.
internal protocol MediaNetSdkInitializer {
    func ensureInitialized(
        accountID: String,
        bundleIdentifier: String,
        then: @escaping (Bool) -> Void
    )
}

/// SPI for the wrapper's static init call. Production uses ``Default``;
/// tests inject a fake to drive the state machine deterministically.
internal protocol MediaNetSdkInitRunner {
    func runInit(
        accountID: String,
        bundleIdentifier: String,
        completion: @escaping (Bool) -> Void
    )
}

internal final class DefaultMediaNetSdkInitRunner: MediaNetSdkInitRunner {
    func runInit(
        accountID: String,
        bundleIdentifier: String,
        completion: @escaping (Bool) -> Void
    ) {
        #if DEBUG
        MediaNetAdSDKClient.shared.logLevel = .debug
        #endif
        // Register the Media.net plugin renderer so bids tagged
        // `rendererName: MediaNetRenderer` render through MNRPluginRenderer
        // instead of falling back to the default Prebid renderer. The
        // renderer's `customerId` is the same Media.net account ID used for
        // the auction.
        MNRPluginRenderer.initialize(customerId: accountID) { registered in
            log.notice("MNRPluginRenderer registered=\(registered, privacy: .public)")
        }
        MediaNetAdSDKClient.shared.configure(
            accountID: accountID,
            bundleIdentifier: bundleIdentifier
        ) { status, _ in
            // Per the wrapper docs, the only two statuses are .succeeded
            // and .failed (plus @unknown default for forward-compat).
            switch status {
            case .succeeded:
                MobileAds.shared.start(completionHandler: nil)
                completion(true)
            case .failed:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
}

/// Default implementation. Thread-safe; the first call kicks off the
/// wrapper init and any concurrent callers queue their callbacks until
/// init finishes. After completion (success or fail), subsequent
/// callers get the cached result without re-init. A failed init is
/// terminal — it never auto-retries.
///
/// Backed by the ``MediaNetSdkInitRunner`` injected at construction so
/// the state machine can be exercised in unit tests without the real
/// wrapper.
internal final class DefaultMediaNetSdkInitializer: MediaNetSdkInitializer {

    private let initRunner: MediaNetSdkInitRunner
    private let lock = NSLock()

    /// `nil` = init not yet finished. `true` = succeeded. `false` = failed.
    private var result: Bool?

    private var started: Bool = false
    private var pending: [(Bool) -> Void] = []

    init(initRunner: MediaNetSdkInitRunner = DefaultMediaNetSdkInitRunner()) {
        self.initRunner = initRunner
    }

    func ensureInitialized(
        accountID: String,
        bundleIdentifier: String,
        then: @escaping (Bool) -> Void
    ) {
        // Fast-path: init finished, cached result.
        lock.lock()
        if let cached = result {
            lock.unlock()
            then(cached)
            return
        }
        pending.append(then)
        let shouldStart = !started
        if shouldStart { started = true }
        lock.unlock()

        guard shouldStart else { return }

        // Synchronous-throw equivalent on iOS is harder (Swift throws are
        // explicit), but a misbehaving wrapper could still e.g. assert.
        // We let any Swift-level exception propagate; the trap will be
        // visible in logs. Init failures from the wrapper come through
        // the completion handler as `.failed`.
        initRunner.runInit(accountID: accountID, bundleIdentifier: bundleIdentifier) { [weak self] ok in
            self?.complete(ok)
        }
    }

    private func complete(_ ok: Bool) {
        var toFire: [(Bool) -> Void] = []
        lock.lock()
        // Terminal: a second complete() (e.g. wrapper fires its listener
        // twice) must not flip the cached result for late callers.
        if result == nil {
            result = ok
            toFire = pending
            pending.removeAll()
        }
        lock.unlock()
        toFire.forEach { $0(ok) }
    }
}

internal enum MediaNetSdkInitializers {
    /// One instance per process; the Media.net wrapper is itself a
    /// process-wide singleton, so init runs at most once.
    static let `default`: MediaNetSdkInitializer = DefaultMediaNetSdkInitializer()
}

private let log = Logger(subsystem: "net.media.bytessdk.adsource.medianet", category: "MediaNetSdkInit")
