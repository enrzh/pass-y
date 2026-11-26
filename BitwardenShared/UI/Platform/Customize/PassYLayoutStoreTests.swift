import BitwardenKit
import SwiftUI
import XCTest

@testable import BitwardenShared

// MARK: - PassYLayoutStoreTests

class PassYLayoutStoreTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        appSettingsStore = MockAppSettingsStore()
    }

    override func tearDown() {
        super.tearDown()
        appSettingsStore = nil
    }

    // MARK: Tests

    /// Without stored preferences the store starts at the defaults and writes nothing.
    @MainActor
    func test_init_defaultsWithoutStoredValue() {
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        XCTAssertEqual(subject.preferences, .default)
        XCTAssertTrue(subject.isDefault)
        XCTAssertNil(appSettingsStore.passYLayoutPreferences)
    }

    /// Stored preferences are loaded.
    @MainActor
    func test_init_loadsStoredValue() {
        var stored = PassYLayoutPreferences.default
        stored.home.hiddenTiles = ["trash"]
        stored.rows.density = .compact
        appSettingsStore.passYLayoutPreferences = stored
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        XCTAssertEqual(subject.preferences, stored)
        XCTAssertFalse(subject.isDefault)
    }

    /// Every change of a slice is written at once; reset restores and writes the defaults.
    @MainActor
    func test_changes_arePersisted_resetRestoresDefaults() {
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        subject.home.tileLayout = .list
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.tileLayout, .list)
        subject.rows.showsIcon = false
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.rows.showsIcon, false)
        subject.codes.groupsDigits = false
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.codes.groupsDigits, false)
        subject.preferences.moveTiles(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.orderedTiles.prefix(2), ["login", "totp"])

        subject.reset()
        XCTAssertTrue(subject.isDefault)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences, .default)

        // A second store on the same settings (the next launch) sees the stored value.
        subject.home.hiddenTiles = ["sshKey"]
        let relaunched = PassYLayoutStore(appSettingsStore: appSettingsStore)
        XCTAssertEqual(relaunched.home.hiddenTiles, ["sshKey"])
    }

    /// The slices are observed independently: a code change does not invalidate a reader of the rows.
    @MainActor
    func test_observation_slicesAreIndependent() {
        let subject = PassYLayoutStore(appSettingsStore: nil)
        var rowsChanged = false
        withObservationTracking {
            _ = subject.rows
        } onChange: {
            rowsChanged = true
        }
        subject.codes.showsCountdownRing = false
        subject.home.tileLayout = .wide
        XCTAssertFalse(rowsChanged, "a codes or home change does not touch the rows slice")
        subject.rows.density = .compact
        XCTAssertTrue(rowsChanged)
    }

    /// The screenshot presets differ from the defaults and each other; an unknown name changes nothing.
    @MainActor
    func test_launchPreset() {
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        subject.applyLaunchPreset(["app", "-PassYLayoutPreset", "unknown"])
        XCTAssertTrue(subject.isDefault)
        subject.applyLaunchPreset(["app", "-PassYLayoutPreset", "list"])
        XCTAssertEqual(subject.home.tileLayout, .list)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.tileLayout, .list)
        let presets = ["default", "wide", "list", "minimal"].compactMap(PassYLayoutPreferences.preset(named:))
        XCTAssertEqual(Set(presets.map { "\($0)" }).count, 4)
    }

    /// The home arrangement: defaults change nothing; hidden tiles and hidden Folders rows move to "More".
    @MainActor
    func test_homeArrangement_hiddenItemsMoveToMore() {
        let tiles = [
            VaultListItem(id: "Types.VerificationCodes", itemType: .group(.totp, 1)),
            VaultListItem(id: "Types.Logins", itemType: .group(.login, 3)),
            VaultListItem(id: "Trash", itemType: .group(.trash, 0)),
        ]
        let folder = VaultListItem(id: "f1", itemType: .group(.folder(id: "f1", name: "Work"), 2))
        let sections = [
            VaultListSection(id: "Favorites", items: [], name: "Favorites"),
            VaultListSection(id: "Folders", items: [folder], name: "Folders"),
        ]
        let plain = PassYHomeArrangement(tiles: tiles, sections: sections, layout: .init())
        XCTAssertEqual(plain.tiles, tiles)
        XCTAssertEqual(plain.sections, sections)
        XCTAssertNil(plain.more, "nothing hidden: no More section")

        var home = PassYLayoutPreferences.Home()
        home.hiddenTiles = ["trash"]
        home.hiddenSections = ["Folders", "Favorites"]
        home.tileOrder = ["login", "totp"]
        let arranged = PassYHomeArrangement(tiles: tiles, sections: sections, layout: home)
        XCTAssertEqual(arranged.tiles.map(\.id), ["Types.Logins", "Types.VerificationCodes"])
        XCTAssertTrue(arranged.sections.isEmpty)
        XCTAssertEqual(arranged.more?.id, PassYHomeArrangement.moreSectionId)
        XCTAssertEqual(arranged.more?.items.map(\.id), ["Trash", "f1"], "hidden tile and folder rows stay reachable")
    }
}
