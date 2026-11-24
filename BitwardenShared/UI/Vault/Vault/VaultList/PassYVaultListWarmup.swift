import Foundation

// MARK: - PassYVaultListWarmup

/// Builds the first vault list (decrypt and sections) right after an unlock, while the unlock page is still on screen,
/// and hands it to the vault home once, so the home's first frame is the finished vault: no blank page and no spinner
/// between Face ID (or the Unlock button) and the first row.
///
/// Before: unlock -> route -> shell -> home appears -> its stream subscribes -> decrypts 2000 items -> first row; the
/// home showed an empty page (and after 0.4 s a spinner) for the whole decrypt. Now the decrypt runs before the route
/// and the home starts with the data (`VaultCoordinator.showList`); its own stream starts as before and keeps it live.
///
/// Security (same design as `ViewItemPreloadCache`): memory only, never written anywhere; started only after the vault
/// was unlocked (the key is needed to decrypt); one hand-over (`take` removes the entry); an entry expires after
/// `lifetime` seconds (timer, also when never taken); `clear()` (every lock, logout, timeout and account switch, see
/// `AppCoordinator`) starts a new generation and cancels a running build, whose late result is then dropped.
@MainActor
enum PassYVaultListWarmup {
    // MARK: Properties

    /// How long a built list waits for the vault home (seconds): only a hand-over between unlock and the first frame.
    static let lifetime: TimeInterval = 5

    /// Increased by `clear()`: a build started in an older generation never stores its result.
    private(set) static var generation = 0

    /// The built list, its filter and when it was built.
    private static var entry: (sections: [VaultListSection], filter: VaultFilterType, date: Date)?

    /// The running build, cancelled by `clear()`.
    private static var building: Task<Void, Never>?

    /// Wipes the entry after `lifetime`.
    private static var expiry: Task<Void, Never>?

    /// Whether an entry is stored (for tests).
    static var hasEntry: Bool { entry != nil }

    /// Whether a build runs (for tests).
    static var isBuilding: Bool { building != nil }

    // MARK: Methods

    /// Builds the first vault list for `filter` and waits for it, at most `timeout` seconds (a slow decrypt then only
    /// means the home loads on its own, as before; the late result is dropped).
    static func build(
        filter: VaultFilterType = .allVaults,
        vaultRepository: VaultRepository,
        timeout: TimeInterval = 3,
    ) async {
        clear()
        let startGeneration = generation
        let run = WarmupRun()
        let task = Task { @MainActor in
            defer { run.finish() }
            guard let publisher = try? await vaultRepository.vaultListPublisher(
                filter: VaultListFilter(filterType: filter, options: [.addTOTPGroup, .addHiddenItemsGroup]),
            ) else { return }
            var iterator = publisher.makeAsyncIterator()
            guard let first = try? await iterator.next(),
                  !run.isFinished, !Task.isCancelled, generation == startGeneration,
                  !first.sections.isEmpty else { return }
            store(first.sections, filter: filter)
        }
        building = task
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            run.finish()
        }
        run.onFinish = {
            task.cancel()
            timeoutTask.cancel()
            if generation == startGeneration { building = nil }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in run.attach(continuation) }
        }
    }

    /// Keeps a list for `take(filter:)`, wiped by a timer `lifetime` seconds after `date` at the latest.
    static func store(_ sections: [VaultListSection], filter: VaultFilterType, date: Date = Date()) {
        entry = (sections, filter, date)
        expiry?.cancel()
        let remaining = max(0, lifetime - Date().timeIntervalSince(date))
        expiry = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if entry?.date == date { entry = nil }
            expiry = nil
        }
    }

    /// The built list for `filter`, removed (nil when absent, for another filter or older than `lifetime`).
    static func take(filter: VaultFilterType, now: Date = Date()) -> [VaultListSection]? {
        guard let taken = entry else { return nil }
        entry = nil
        expiry?.cancel()
        expiry = nil
        guard taken.filter == filter, now.timeIntervalSince(taken.date) <= lifetime else { return nil }
        return taken.sections
    }

    /// Drops the entry, cancels a running build and starts a new generation, so no late result is stored.
    static func clear() {
        generation += 1
        building?.cancel()
        building = nil
        expiry?.cancel()
        expiry = nil
        entry = nil
    }
}

/// One build: finished once the build ends, `clear()` cancels it or the timeout fires.
@MainActor
private final class WarmupRun {
    private(set) var isFinished = false
    var onFinish: (@MainActor () -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?

    func attach(_ continuation: CheckedContinuation<Void, Never>) {
        if isFinished { continuation.resume() } else { self.continuation = continuation }
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish?()
        onFinish = nil
        continuation?.resume()
        continuation = nil
    }
}
