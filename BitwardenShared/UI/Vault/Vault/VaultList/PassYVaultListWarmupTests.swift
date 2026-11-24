import Combine
import XCTest

@testable import BitwardenShared

/// The unlock warm-up of the vault list (`PassYVaultListWarmup`) and the processor-owned vault list stream: a one-shot,
/// expiring, memory-only hand-over that a lock (`clear()`) drops, and a stream that survives a back to the home page
/// but ends with the vault session.
@MainActor
class PassYVaultListWarmupTests: BitwardenTestCase {
    private let section = VaultListSection(id: "1", items: [.fixture()], name: "Section")

    override func setUp() {
        super.setUp()
        PassYVaultListWarmup.clear()
    }

    override func tearDown() {
        PassYVaultListWarmup.clear()
        super.tearDown()
    }

    /// A build hands the first list over once, for the same filter only.
    func test_build_takeOnce_sameFilterOnly() async {
        let repository = MockVaultRepository()
        repository.vaultListSubject.value = VaultListData(sections: [section])
        await PassYVaultListWarmup.build(vaultRepository: repository)
        XCTAssertNil(PassYVaultListWarmup.take(filter: .myVault), "another filter gets nothing (and the entry is gone)")

        await PassYVaultListWarmup.build(vaultRepository: repository)
        XCTAssertEqual(PassYVaultListWarmup.take(filter: .allVaults), [section])
        XCTAssertNil(PassYVaultListWarmup.take(filter: .allVaults), "taken once")
    }

    /// An empty vault stores nothing (the home then loads and decides about a sync on its own).
    func test_build_emptyVault_storesNothing() async {
        let repository = MockVaultRepository()
        await PassYVaultListWarmup.build(vaultRepository: repository)
        XCTAssertFalse(PassYVaultListWarmup.hasEntry)
    }

    /// An entry expires: never handed over after `lifetime`, and wiped by its timer even when never taken.
    func test_store_expires() async throws {
        PassYVaultListWarmup.store([section], filter: .allVaults, date: Date().addingTimeInterval(-PassYVaultListWarmup.lifetime - 1))
        XCTAssertNil(PassYVaultListWarmup.take(filter: .allVaults), "expired")

        PassYVaultListWarmup.store([section], filter: .allVaults, date: Date().addingTimeInterval(-PassYVaultListWarmup.lifetime + 0.2))
        try await waitForAsync { !PassYVaultListWarmup.hasEntry }
    }

    /// A lock while the list is still being built: the build is cancelled and its late result is never stored.
    func test_clear_whileBuilding_dropsLateResult() async throws {
        // No value yet: the build waits for the first emission.
        let subject = PassthroughVaultListRepository()
        let task = Task { await PassYVaultListWarmup.build(vaultRepository: subject, timeout: 10) }
        try await waitForAsync { PassYVaultListWarmup.isBuilding && subject.subscribed }
        let generation = PassYVaultListWarmup.generation
        PassYVaultListWarmup.clear()
        XCTAssertGreaterThan(PassYVaultListWarmup.generation, generation)
        subject.subject.send(VaultListData(sections: [section]))
        await task.value
        XCTAssertFalse(PassYVaultListWarmup.hasEntry, "the late result was dropped")
    }

    /// A build that takes longer than its timeout returns and leaves nothing behind.
    func test_build_timeout_leavesNoEntry() async throws {
        let subject = PassthroughVaultListRepository()
        let start = Date()
        await PassYVaultListWarmup.build(vaultRepository: subject, timeout: 0.2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5)
        subject.subject.send(VaultListData(sections: [section]))
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(PassYVaultListWarmup.hasEntry)
    }
}

/// The vault list stream belongs to `VaultListProcessor`: appearing again (back from a pushed page) does not restart
/// it (no second decrypt inside the pop transition), and the end of the vault session ends it and drops the list.
@MainActor
class PassYVaultListStreamTests: BitwardenTestCase {
    private let section = VaultListSection(id: "1", items: [.fixture()], name: "Section")

    private func makeSubject(_ repository: MockVaultRepository) -> VaultListProcessor {
        VaultListProcessor(
            coordinator: MockCoordinator<VaultRoute, AuthAction>().asAnyCoordinator(),
            masterPasswordRepromptHelper: MockMasterPasswordRepromptHelper(),
            services: ServiceContainer.withMocks(vaultRepository: repository),
            state: VaultListState(),
            vaultItemMoreOptionsHelper: MockVaultItemMoreOptionsHelper(),
        )
    }

    /// A second `.streamVaultList` for the same filter (the home appearing again) keeps the running stream.
    func test_streamVaultList_reappear_keepsStream_sessionEndClears() async throws {
        let repository = MockVaultRepository()
        repository.vaultListSubject.value = VaultListData(sections: [section])
        let subject = makeSubject(repository)
        await subject.perform(.streamVaultList)
        let stream = try XCTUnwrap(subject.vaultListStreamTask)
        try await waitForAsync { subject.state.loadingState == .data([self.section]) }

        await subject.perform(.streamVaultList)
        XCTAssertEqual(subject.vaultListStreamTask, stream, "not restarted")

        NotificationCenter.default.post(name: .passyVaultSessionEnded, object: nil)
        try await waitForAsync { subject.vaultListStreamTask == nil }
        XCTAssertEqual(subject.state.loadingState, .loading(nil), "the decrypted list is dropped")
    }

    /// A filter change restarts the stream.
    func test_streamVaultList_filterChange_restarts() async throws {
        let repository = MockVaultRepository()
        let subject = makeSubject(repository)
        await subject.perform(.streamVaultList)
        let stream = try XCTUnwrap(subject.vaultListStreamTask)
        subject.state.vaultFilterType = .myVault
        await subject.perform(.streamVaultList)
        XCTAssertNotEqual(subject.vaultListStreamTask, stream)
        XCTAssertTrue(stream.isCancelled)
    }

    /// The running stream does not keep the processor (and its decrypted list) alive.
    func test_streamVaultList_doesNotRetainProcessor() async throws {
        let repository = MockVaultRepository()
        repository.vaultListSubject.value = VaultListData(sections: [section])
        var subject: VaultListProcessor? = makeSubject(repository)
        weak var weakSubject = subject
        await subject?.perform(.streamVaultList)
        try await waitForAsync { subject?.state.loadingState == .data([self.section]) }
        subject = nil
        try await waitForAsync { weakSubject == nil }
    }
}

/// A repository whose vault list publisher emits only what the test sends.
private final class PassthroughVaultListRepository: MockVaultRepository {
    let subject = PassthroughSubject<VaultListData, Error>()
    private(set) var subscribed = false

    override func vaultListPublisher(
        filter: VaultListFilter,
    ) async throws -> AsyncThrowingPublisher<AnyPublisher<VaultListData, Error>> {
        subscribed = true
        return subject.eraseToAnyPublisher().values
    }
}
