import BitwardenKit
import BitwardenKitMocks
import BitwardenSdk
import SwiftUI
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - VaultListPerfTests

/// Unit-level responsiveness measurements of the vault home with a 2000 item vault (the real UI numbers come from
/// `PassYPerfTests` in the UI test target). The view is hosted in a window; every measurement forces layout, so the
/// SwiftUI bodies really run. The printed `PERF unit ...` lines are the before/after record in the README.
///
/// The counters are deterministic (row bodies evaluated, child stores created), the milliseconds are not.
@MainActor
final class VaultListPerfTests: BitwardenTestCase {
    // MARK: Properties

    var processor: MockProcessor<VaultListState, VaultListAction, VaultListEffect>!
    var window: UIWindow!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        processor = MockProcessor(state: VaultListState(itemTypesUserCanCreate: CipherType.canCreateCases))
        let view = VaultListView(
            store: Store(processor: processor),
            timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
        )
        let navigation = UINavigationController(rootViewController: UIHostingController(rootView: view))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        settle()
    }

    override func tearDown() {
        super.tearDown()
        window.isHidden = true
        window = nil
        processor = nil
    }

    // MARK: Helpers

    /// A vault with category tiles, a few folders and `count` logins in "No folder".
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
    func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        window.layoutIfNeeded()
    }

    /// Runs `block`, then returns the elapsed milliseconds and the counter deltas.
    func measureBlock(_ block: () -> Void) -> (milliseconds: Double, rowBodies: Int, childStores: Int) {
        let bodiesBefore = PassYPerf.rowBodyCount
        let storesBefore = StorePerfCounters.childStores
        let start = CFAbsoluteTimeGetCurrent()
        block()
        settle()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        return (elapsed, PassYPerf.rowBodyCount - bodiesBefore, StorePerfCounters.childStores - storesBefore)
    }

    func report(_ name: String, _ result: (milliseconds: Double, rowBodies: Int, childStores: Int)) {
        print("PERF unit \(name) ms=\(String(format: "%.1f", result.milliseconds)) "
            + "rowBodies=\(result.rowBodies) childStores=\(result.childStores)")
    }

    // MARK: Tests

    /// First layout after the 2000 item list arrived.
    func test_perf_listLoad_2000() {
        let data = sections(count: 2000)
        let result = measureBlock { processor.state.loadingState = .data(data) }
        report("listLoad2000", result)
    }

    /// 30 changes of state that has nothing to do with the rows (toast on/off): the rows must not be rebuilt.
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
}
