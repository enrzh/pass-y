import Foundation

// MARK: - PassYVaultListWarmup

/// Builds the first vault list (decrypt and sections) right after an unlock, at the same time as the vault shell is
/// built, and hands it to the vault home once.
///
/// Before: unlock -> route -> shell (~200 ms) -> home appears -> its stream subscribes -> decrypts 2000 items (~300 ms)
/// -> first row, one after the other; the home showed an empty page (and after 0.4 s a spinner) for the whole decrypt.
/// Now the decrypt starts at the unlock and runs while the shell is built: the home takes the finished list in its
/// first frame when it is ready by then (`VaultCoordinator.showList`), else its stream waits for this build instead of
/// starting a second decrypt (`sections(filter:)`), then subscribes as before and keeps the list live.
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

    /// The running build's state (finished by the build, its timeout or `clear()`) and its filter.
    private static var run: (run: WarmupRun, filter: VaultFilterType)?

    /// Wipes the entry after `lifetime`.
    private static var expiry: Task<Void, Never>?

    /// Whether an entry is stored (for tests).
    static var hasEntry: Bool { entry != nil }

    /// Whether a build runs (for tests).
    static var isBuilding: Bool { building != nil }

    // MARK: Methods

    /// Builds the first vault list for `filter` and waits for it (see `start`).
    static func build(
        filter: VaultFilterType = .allVaults,
        vaultRepository: VaultRepository,
        timeout: TimeInterval = 3,
    ) async {
        start(filter: filter, vaultRepository: vaultRepository, timeout: timeout)
        await waitForBuild()
    }

    /// The built list for `filter`: waits for a running build of that filter first (never a second decrypt), then takes
    /// the entry (nil when there is none: the caller loads on its own).
    static func sections(filter: VaultFilterType) async -> [VaultListSection]? {
        if let current = run, current.filter == filter { await waitForBuild() }
        return take(filter: filter)
    }

    /// Waits until the running build ended (built, timed out or cleared); returns at once without one.
    static func waitForBuild() async {
        guard let current = run?.run else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in current.attach(continuation) }
        }
    }

    /// Starts building the first vault list for `filter` and returns at once. The build ends after at most `timeout`
    /// seconds (a slow decrypt then only means the home loads on its own, as before; the late result is dropped).
    static func start(
        filter: VaultFilterType = .allVaults,
        vaultRepository: VaultRepository,
        timeout: TimeInterval = 3,
    ) {
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
            if generation == startGeneration {
                building = nil
                self.run = nil
            }
        }
        self.run = (run, filter)
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
        let finishing = run?.run
        run = nil
        finishing?.finish() // resumes waiters; the build may no longer store
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
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func attach(_ continuation: CheckedContinuation<Void, Never>) {
        if isFinished { continuation.resume() } else { continuations.append(continuation) }
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinish?()
        onFinish = nil
        continuations.forEach { $0.resume() }
        continuations = []
    }
}
