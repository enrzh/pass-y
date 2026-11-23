import BitwardenSdk
import XCTest

@testable import BitwardenShared

/// ui-r9 checks that need no UI: the launch screen, the preload hand-over, the release hygiene of the perf hooks, no
/// web vault links, no watch code.
class PassYUiR9Tests: BitwardenTestCase {
    /// The repository root, found from this file (`#filePath` is in the checkout, which the simulator shares).
    private var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// The launch screen is a plain system background: no logo, no title, no image view.
    func test_launchScreen_isPlain() throws {
        let storyboard = try read("Bitwarden/Application/Support/Resources/LaunchScreen.storyboard")
        XCTAssertFalse(storyboard.contains("imageView"), "no logo")
        XCTAssertFalse(storyboard.contains("logoBitwarden"))
        XCTAssertFalse(storyboard.contains("<label"), "no title")
        XCTAssertTrue(storyboard.contains("systemBackgroundColor"), "neutral system background")
    }

    /// The spec has no watch targets and the Mac and visionOS "Designed for iPad" support is off.
    func test_projectSpec_noWatch_noMacNoVision() throws {
        let spec = try read("project-pm.yml")
        XCTAssertFalse(spec.contains("Watch"), "no watch target or dependency")
        XCTAssertFalse(spec.contains("watchOS"))
        XCTAssertTrue(spec.contains("SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO"))
        XCTAssertTrue(spec.contains("SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO"))
        XCTAssertTrue(spec.contains("TARGETED_DEVICE_FAMILY: \"1,2\""))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("BitwardenWatchApp").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("BitwardenWatchShared").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("BitwardenWatchWidgetExtension").path,
        ))
    }

    /// The perf counters and signposts exist only in DEBUG builds.
    func test_perfHooks_onlyInDebug() throws {
        let source = try read("BitwardenShared/UI/Platform/Application/Utilities/PassYPerf.swift")
        let debugPart = source.components(separatedBy: "#else").first ?? ""
        XCTAssertTrue(debugPart.contains("#if DEBUG"))
        XCTAssertTrue(debugPart.contains("signposter"))
        let releasePart = source.components(separatedBy: "#else").last ?? ""
        XCTAssertFalse(releasePart.contains("OSSignposter"), "the release stubs have no signposter")
        XCTAssertFalse(releasePart.contains("VaultListLoad"), "and no signpost names")
        XCTAssertFalse(releasePart.contains("TapToPush"))
    }

    /// No production source opens the web vault from a button any more.
    func test_noWebVaultLinks() throws {
        for file in [
            "BitwardenShared/UI/Platform/Settings/Settings/About/AboutProcessor.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/About/AboutView.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/AccountSecurity/AccountSecurityProcessor.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/Vault/VaultSettingsProcessor.swift",
            "BitwardenShared/UI/Auth/Login/TwoFactorAuth/TwoFactorAuthProcessor.swift",
        ] {
            let source = try read(file)
            // (the Duo callback of the two-factor page still needs the server's web vault base URL; it is no link)
            if !file.contains("TwoFactorAuth") { XCTAssertFalse(source.contains("webVaultURL"), file) }
            XCTAssertFalse(source.contains("importItemsURL"), file)
            XCTAssertFalse(source.contains("recoveryCodeURL"), file)
            XCTAssertFalse(source.contains("twoStepLoginUrl"), file)
        }
    }

    /// The preloaded item state is handed over once and expires (no decrypted data stays around).
    @MainActor
    func test_preloadCache_takeOnce_andExpires() {
        ViewItemPreloadCache.clear()
        let state = ViewItemState()
        ViewItemPreloadCache.store(state, id: "a")
        XCTAssertNotNil(ViewItemPreloadCache.take(id: "a"))
        XCTAssertNil(ViewItemPreloadCache.take(id: "a"), "taken once")

        ViewItemPreloadCache.store(state, id: "b", date: Date().addingTimeInterval(-ViewItemPreloadCache.lifetime - 1))
        XCTAssertNil(ViewItemPreloadCache.take(id: "b"), "expired")
    }

    /// The server text of the menus is the URL without a trailing slash.
    func test_serverText() throws {
        XCTAssertEqual(try XCTUnwrap(URL(string: "https://vault.example.com/")).passYServerText, "https://vault.example.com")
        XCTAssertEqual(try XCTUnwrap(URL(string: "http://localhost:8089")).passYServerText, "http://localhost:8089")
    }
}

/// ui-r9 fix: nothing in the shell or the loading indicator can keep the app from idling.
class PassYUiR9IdleTests: BitwardenTestCase {
    private func read(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }

    /// The loading indicator has no animation construct and uses the system spinner.
    func test_delayedIndicator_noAnimationConstructs() throws {
        let source = try read("BitwardenShared/UI/Platform/Application/LoadingView.swift")
        let indicator = source.components(separatedBy: "// MARK: - LoadingView").first ?? ""
        XCTAssertFalse(indicator.contains("withAnimation("), "no withAnimation")
        XCTAssertFalse(indicator.contains(".transition("), "no transition")
        XCTAssertFalse(indicator.contains("CircularActivityIndicator"), "no custom repeat-forever spinner")
        XCTAssertTrue(indicator.contains("ProgressView()"))
    }

    /// The fade view disables implicit layer animations.
    @MainActor
    func test_edgeFade_hasNoImplicitAnimations() {
        let fade = PassYEdgeFadeView(edge: .bottom)
        fade.frame = CGRect(x: 0, y: 0, width: 300, height: 120)
        fade.layoutIfNeeded()
        fade.frame = CGRect(x: 0, y: 0, width: 300, height: 140)
        fade.layoutIfNeeded()
        fade.layer.sublayers?.forEach { XCTAssertNil($0.animationKeys(), "no animation on \($0)") }
    }
}

/// ui-r9 fix: the vault home has no system refresh control that can spin for the whole length of a sync.
class PassYUiR9NoRefreshControlTests: BitwardenTestCase {
    func test_vaultListView_hasNoRefreshable() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        let source = try String(
            contentsOf: url.appendingPathComponent("BitwardenShared/UI/Vault/Vault/VaultList/VaultListView.swift"),
            encoding: .utf8,
        )
        XCTAssertFalse(source.contains(".refreshable"), "no pull-to-refresh on the vault home (sync is in the avatar menu)")
        XCTAssertTrue(source.contains("sync: { Task { await store.perform(.refreshVault) } }"), "Sync now stays")
    }
}

/// ui-r9 fix round: the preload hand-over has a timeout and a successful preload fills the cache.
@MainActor
class PassYUiR9PreloadTests: BitwardenTestCase {
    /// A fetch that hangs must not hold the tap back: after the timeout the item opens without a preloaded state.
    func test_preload_timesOut() async {
        ViewItemPreloadCache.clear()
        let repository = MockVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: "slow"))
        repository.fetchCipherDelay = 3
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        let start = Date()
        await ViewItemPreloadCache.preload(id: "slow", services: services, timeout: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5, "returned after the timeout, not after the fetch")
        XCTAssertNil(ViewItemPreloadCache.take(id: "slow"))
    }

    /// A quick fetch fills the cache for the view.
    func test_preload_fillsCache() async {
        ViewItemPreloadCache.clear()
        let repository = MockVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: "fast"))
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        await ViewItemPreloadCache.preload(id: "fast", services: services)
        XCTAssertNotNil(ViewItemPreloadCache.take(id: "fast"))
    }
}

/// preload-sec: a late preload result never lands in the cache after a timeout or a clear (lock, logout, account
/// switch), and a clear cancels the running fetch.
@MainActor
class PassYPreloadSecurityTests: BitwardenTestCase {
    /// Starts a preload whose fetch takes `delay` seconds and waits until its fetch is running.
    private func startSlowPreload(
        id: String,
        delay: TimeInterval = 3,
        timeout: TimeInterval = 10,
    ) async throws -> (task: Task<Bool, Never>, repository: MockVaultRepository) {
        let repository = MockVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: id))
        repository.fetchCipherDelay = delay
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        let task = Task { await ViewItemPreloadCache.preload(id: id, services: services, timeout: timeout) }
        try await waitForAsync { ViewItemPreloadCache.inFlightCount == 1 }
        return (task, repository)
    }

    /// A fetch whose result arrives after `clear()` does not store it, and the clear cancels the fetch at once.
    func test_clear_cancelsInFlightFetch_andDropsLateResult() async throws {
        ViewItemPreloadCache.clear()
        let (task, repository) = try await startSlowPreload(id: "late")
        let start = Date()
        ViewItemPreloadCache.clear()
        XCTAssertEqual(ViewItemPreloadCache.inFlightCount, 0, "the running fetch is cancelled")

        let stillUnlocked = await task.value
        XCTAssertFalse(stillUnlocked, "the caller learns the cache was cleared and must not open the item")
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5, "cancelled, not waited out")
        // The (cancelled) fetch still returned the decrypted cipher: the guard, not the mock, dropped it.
        XCTAssertEqual(repository.fetchCipherId, "late")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(ViewItemPreloadCache.take(id: "late"), "the late result was not stored")
    }

    /// The timeout path cancels the fetch and leaves no entry, also after the fetch would have finished.
    func test_preload_timeout_leavesNoEntry() async throws {
        ViewItemPreloadCache.clear()
        let repository = MockVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: "slow"))
        repository.fetchCipherDelay = 0.5
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        let stillUnlocked = await ViewItemPreloadCache.preload(id: "slow", services: services, timeout: 0.1)
        XCTAssertTrue(stillUnlocked, "a timeout is not a lock: the item opens and loads on its own")
        XCTAssertEqual(ViewItemPreloadCache.inFlightCount, 0, "the fetch is cancelled on timeout")
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertNil(ViewItemPreloadCache.take(id: "slow"), "no late entry after the timeout")
    }

    /// A fetch that ignores cancellation and finishes after `clear()` still does not store its decrypted result.
    func test_lateStoreAfterClear_nonCancellableFetch_isDropped() async throws {
        ViewItemPreloadCache.clear()
        let repository = NonCancellableVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: "stubborn"))
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        let task = Task { await ViewItemPreloadCache.preload(id: "stubborn", services: services, timeout: 10) }
        try await waitForAsync { ViewItemPreloadCache.inFlightCount == 1 }
        ViewItemPreloadCache.clear()
        let stillUnlocked = await task.value
        XCTAssertFalse(stillUnlocked)
        XCTAssertTrue(repository.didFinishFetch, "the fetch ran to its end despite the cancel")
        XCTAssertNil(ViewItemPreloadCache.take(id: "stubborn"), "the late result was dropped")
    }

    /// An entry that is never taken is wiped by its timer after `lifetime`, without another preload or clear.
    func test_store_untakenEntry_isWipedByTimer() async throws {
        ViewItemPreloadCache.clear()
        let state = try XCTUnwrap(ViewItemState(cipherView: .fixture(id: "ttl"), hasPremium: false, iconBaseURL: nil))
        // Stored as if 0.3 s before its end of life: the timer fires after the remaining 0.3 s.
        ViewItemPreloadCache.store(state, id: "ttl", date: Date().addingTimeInterval(-ViewItemPreloadCache.lifetime + 0.3))
        XCTAssertEqual(ViewItemPreloadCache.entryCount, 1)
        try await waitForAsync({ ViewItemPreloadCache.entryCount == 0 }, timeout: 2)
        XCTAssertEqual(ViewItemPreloadCache.entryCount, 0, "wiped by the timer, nothing else ran")
    }

    /// `clear()` starts a new generation, so a preload started before it never stores its result.
    func test_generation_changesOnClear() {
        let before = ViewItemPreloadCache.generation
        ViewItemPreloadCache.clear()
        XCTAssertEqual(ViewItemPreloadCache.generation, before + 1)
    }

    /// A normal preload reports that the vault is still open and fills the cache.
    func test_preload_success_returnsTrue() async {
        ViewItemPreloadCache.clear()
        let repository = MockVaultRepository()
        repository.fetchCipherResult = .success(.fixture(id: "ok"))
        let services = ServiceContainer.withMocks(vaultRepository: repository)
        let stillUnlocked = await ViewItemPreloadCache.preload(id: "ok", services: services)
        XCTAssertTrue(stillUnlocked)
        XCTAssertEqual(ViewItemPreloadCache.inFlightCount, 0)
        XCTAssertNotNil(ViewItemPreloadCache.take(id: "ok"))
    }
}

/// A vault repository whose cipher fetch takes 0.4 s and ignores task cancellation (like a busy SDK decrypt).
private final class NonCancellableVaultRepository: MockVaultRepository {
    var didFinishFetch = false

    override func fetchCipher(withId id: String) async throws -> CipherView? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { continuation.resume() }
        }
        didFinishFetch = true
        return try await super.fetchCipher(withId: id)
    }
}
