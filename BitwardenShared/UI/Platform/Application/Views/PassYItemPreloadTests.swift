import BitwardenSdk
import XCTest

@testable import BitwardenShared

/// The item preload hand-over has a timeout and a successful preload fills the cache (formerly `PassYUiR9PreloadTests`).
@MainActor
class PassYItemPreloadTests: BitwardenTestCase {
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
