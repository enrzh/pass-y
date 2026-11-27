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
        stored.home.tileRows = ["trash"]
        stored.home.cardColors = .filled
        appSettingsStore.passYLayoutPreferences = stored
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        XCTAssertEqual(subject.preferences, stored)
        XCTAssertFalse(subject.isDefault)
    }

    /// Every change of a slice is written at once; reset restores and writes the defaults.
    @MainActor
    func test_changes_arePersisted_resetRestoresDefaults() {
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        subject.home.cardColors = .filled
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.cardColors, .filled)
        subject.rows.showsIcon = false
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.rows.showsIcon, false)
        subject.codes.groupsDigits = false
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.codes.groupsDigits, false)
        subject.preferences.moveElements(folders: [], fromOffsets: IndexSet(integer: 0), toOffset: 2)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.orderedTiles.prefix(2), ["login", "totp"])

        subject.reset()
        XCTAssertTrue(subject.isDefault)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences, .default)

        // A second store on the same settings (the next launch) sees the stored value.
        subject.home.tileRows = ["sshKey"]
        subject.home.folderCards = ["folder:f1"]
        let relaunched = PassYLayoutStore(appSettingsStore: appSettingsStore)
        XCTAssertEqual(relaunched.home.tileRows, ["sshKey"])
        XCTAssertEqual(relaunched.home.folderCards, ["folder:f1"])
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
        subject.home.cardColors = .filled
        XCTAssertFalse(rowsChanged, "a codes or home change does not touch the rows slice")
        subject.rows.showsSubtitle = false
        XCTAssertTrue(rowsChanged)
    }

    /// The screenshot presets differ from the defaults and each other; an unknown name changes nothing.
    @MainActor
    func test_launchPreset() {
        let subject = PassYLayoutStore(appSettingsStore: appSettingsStore)
        subject.applyLaunchPreset(["app", "-PassYLayoutPreset", "unknown"])
        XCTAssertTrue(subject.isDefault)
        subject.applyLaunchPreset(["app", "-PassYLayoutPreset", "filled"])
        XCTAssertEqual(subject.home.cardColors, .filled)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.cardColors, .filled)
        let presets = ["default", "filled", "rows", "minimal"].compactMap(PassYLayoutPreferences.preset(named:))
        XCTAssertEqual(Set(presets.map { "\($0)" }).count, 4)
    }

    /// The home arrangement: defaults change nothing; switched tiles become rows of the Types section, switched
    /// folders cards (and leave the folder rows); rows of hidden sections move to "More"; unknown folders are ignored.
    @MainActor
    func test_homeArrangement_cardsRowsAndMore() {
        let tiles = [
            VaultListItem(id: "Types.VerificationCodes", itemType: .group(.totp, 1)),
            VaultListItem(id: "Types.Logins", itemType: .group(.login, 3)),
            VaultListItem(id: "Trash", itemType: .group(.trash, 0)),
        ]
        let work = VaultListItem(id: "f1", itemType: .group(.folder(id: "f1", name: "Work"), 2))
        let home = VaultListItem(id: "f2", itemType: .group(.folder(id: "f2", name: "Home"), 1))
        let noFolder = VaultListItem(id: "NoFolderFolderItem", itemType: .group(.noFolder, 4))
        let sections = [
            VaultListSection(id: "Favorites", items: [], name: "Favorites"),
            VaultListSection(id: "Folders", items: [work, home, noFolder], name: "Folders"),
        ]
        let plain = PassYHomeArrangement(tiles: tiles, sections: sections, layout: .init())
        XCTAssertEqual(plain.cards, tiles)
        XCTAssertEqual(plain.sections, sections)
        XCTAssertNil(plain.more, "nothing hidden: no More section")

        // Trash as a row, Work and No folder as cards (Work first), a deleted folder in the order.
        var layout = PassYLayoutPreferences.Home()
        layout.tileRows = ["trash"]
        layout.folderCards = ["folder:f1", "noFolder", "folder:deleted"]
        layout.tileOrder = ["folder:deleted", "folder:f1", "login", "totp"]
        let arranged = PassYHomeArrangement(tiles: tiles, sections: sections, layout: layout)
        XCTAssertEqual(arranged.cards.map(\.id), ["f1", "Types.Logins", "Types.VerificationCodes", "NoFolderFolderItem"])
        XCTAssertEqual(arranged.cardIds, ["folder:f1", "login", "totp", "noFolder"])
        XCTAssertEqual(arranged.sections.map(\.id), ["PassYTypes", "Favorites", "Folders"])
        XCTAssertEqual(arranged.sections[0].items.map(\.id), ["Trash"], "the switched tile is a row, not gone")
        XCTAssertEqual(arranged.sections[2].items.map(\.id), ["f2"], "folders shown as cards are not duplicated")
        XCTAssertNil(arranged.more)

        // Every folder a card: no empty Folders section. Hidden Types section: its rows under More.
        layout.folderCards = ["folder:f1", "folder:f2", "noFolder"]
        layout.hiddenSections = ["PassYTypes", "Favorites"]
        let allCards = PassYHomeArrangement(tiles: tiles, sections: sections, layout: layout)
        XCTAssertEqual(allCards.sections.map(\.id), [])
        XCTAssertEqual(allCards.cards.count, 5)
        XCTAssertEqual(allCards.more?.id, PassYHomeArrangement.moreSectionId)
        XCTAssertEqual(allCards.more?.items.map(\.id), ["Trash"], "rows of a hidden section stay reachable")
    }

    /// The home element identifiers: type tiles keep their tile identifier, folders are keyed by id.
    func test_homeElementIds() {
        XCTAssertEqual(VaultListItem(id: "x", itemType: .group(.login, 1)).passYHomeElementId, "login")
        XCTAssertEqual(
            VaultListItem(id: "f1", itemType: .group(.folder(id: "f1", name: "A"), 1)).passYHomeElementId,
            "folder:f1",
        )
        XCTAssertEqual(VaultListItem(id: "n", itemType: .group(.noFolder, 1)).passYHomeElementId, "noFolder")
        let collection = VaultListItem(id: "c1", itemType: .group(.collection(id: "c1", name: "C", organizationId: "o"), 1))
        XCTAssertFalse(collection.isPassYHomeElement)
        XCTAssertTrue(VaultListItem(id: "n", itemType: .group(.noFolder, 1)).isPassYHomeElement)
    }
}
