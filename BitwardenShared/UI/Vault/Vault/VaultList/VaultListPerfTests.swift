import BitwardenKit
import BitwardenKitMocks
import BitwardenSdk
import SwiftUI
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - VaultListPerfTests

/// Unit-level responsiveness measurements of the vault home with a 2000 item vault (the real UI numbers come from
/// `PassYPerfTests` in the UI test target). The view is hosted in a hostWindow; every measurement forces layout, so the
/// SwiftUI bodies really run. The printed `PERF unit ...` lines are the before/after record in the README.
///
/// The counters are deterministic (row bodies evaluated, child stores created), the milliseconds are not.
final class VaultListPerfTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<VaultListState, VaultListAction, VaultListEffect>!
    var hostWindow: UIWindow!

    // MARK: Setup & Teardown

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        processor = MockProcessor(state: VaultListState(itemTypesUserCanCreate: CipherType.canCreateCases))
        let view = VaultListView(
            store: Store(processor: processor),
            timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
        )
        let navigation = UINavigationController(rootViewController: UIHostingController(rootView: view))
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        hostWindow.rootViewController = navigation
        hostWindow.makeKeyAndVisible()
        settle()
    }

    @MainActor
    override func tearDown() async throws {
        try await super.tearDown()
        hostWindow.isHidden = true
        hostWindow = nil
        processor = nil
    }

    // MARK: Helpers

    /// A vault with category tiles, a few folders and `count` logins in "No folder".
    @MainActor
    func sections(count: Int) -> [VaultListSection] {
        let tiles = [
            VaultListItem.fixtureGroup(id: "tile-login", group: .login, count: count),
            VaultListItem.fixtureGroup(id: "tile-card", group: .card, count: 0),
            VaultListItem.fixtureGroup(id: "tile-trash", group: .trash, count: 0),
        ]
        let folders = (0 ..< 5).map {
            VaultListItem.fixtureGroup(id: "folder-\($0)", group: .folder(id: "f\($0)", name: "Folder \($0)"), count: 10)
        }
        let items = (0 ..< count).map { index in
            VaultListItem.fixture(cipherListView: .fixture(
                id: "id-\(index)",
                name: "Perf Item \(String(format: "%04d", index))",
                subtitle: "user\(index)@example.test",
            ))
        }
        return [
            VaultListSection(id: "Types", items: tiles, name: "Types"),
            VaultListSection(id: "Folders", items: folders, name: "Folders"),
            VaultListSection(id: "NoFolder", items: items, name: "No Folder"),
        ]
    }

    /// Lets SwiftUI commit and forces layout so that all pending bodies are evaluated.
    @MainActor
    func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        hostWindow.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        hostWindow.layoutIfNeeded()
    }

    /// Runs `block`, then returns the elapsed milliseconds and the counter deltas. `rowBodies` counts cell bodies,
    /// `rowBuilds` the rows the list builders created (before ui-r8 each of them also created a child store).
    @MainActor
    func measureBlock(_ block: () -> Void) -> Result {
        let bodiesBefore = PassYPerf.cellBodyCount + PassYPerf.rowBodyCount
        let buildsBefore = PassYPerf.rowBuildCount
        let storesBefore = StorePerfCounters.childStores
        let start = CFAbsoluteTimeGetCurrent()
        block()
        settle()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return Result(
            milliseconds: elapsed,
            rowBodies: PassYPerf.cellBodyCount + PassYPerf.rowBodyCount - bodiesBefore,
            rowBuilds: PassYPerf.rowBuildCount - buildsBefore,
            childStores: StorePerfCounters.childStores - storesBefore,
        )
    }

    struct Result {
        let milliseconds: Double
        let rowBodies: Int
        let rowBuilds: Int
        let childStores: Int
    }

    func report(_ name: String, _ result: Result) {
        print("PERF unit \(name) ms=\(String(format: "%.1f", result.milliseconds)) "
            + "rowBodies=\(result.rowBodies) rowBuilds=\(result.rowBuilds) childStores=\(result.childStores)")
    }

    // MARK: Tests

    /// First layout after the 2000 item list arrived.
    @MainActor
    func test_perf_listLoad_2000() {
        let data = sections(count: 2000)
        let result = measureBlock { processor.state.loadingState = .data(data) }
        report("listLoad2000", result)
    }

    /// 30 changes of state that has nothing to do with the rows (toast on/off): the rows must not be rebuilt.
    @MainActor
    func test_perf_unrelatedStateChurn_2000() {
        processor.state.loadingState = .data(sections(count: 2000))
        settle()
        let result = measureBlock {
            for index in 0 ..< 30 {
                processor.state.toast = index.isMultiple(of: 2) ? Toast(title: "T\(index)") : nil
                settle()
            }
        }
        report("unrelatedChurn30x2000", result)
    }

    /// Typing 14 characters: every keystroke changes the search text in the state.
    @MainActor
    func test_perf_searchTextChurn_2000() {
        processor.state.loadingState = .data(sections(count: 2000))
        settle()
        let text = Array("Perf Item 1999")
        let result = measureBlock {
            for index in 1 ... text.count {
                processor.state.searchText = String(text[0 ..< index])
                settle()
            }
        }
        report("searchTextChurn14x2000", result)
    }

    /// ui-r8 invariants (counters, no time thresholds): unrelated state changes neither build rows again nor create
    /// child stores; typing builds rows only for the search results.
    @MainActor
    func test_unrelatedChanges_doNotRebuildRows() {
        processor.state.loadingState = .data(sections(count: 2000))
        settle()
        let result = measureBlock {
            for index in 0 ..< 10 {
                processor.state.toast = index.isMultiple(of: 2) ? Toast(title: "T\(index)") : nil
                settle()
            }
        }
        XCTAssertEqual(result.childStores, 0, "no child store per row")
        XCTAssertEqual(result.rowBuilds, 0, "rows are not built again for a toast change")
    }
}
