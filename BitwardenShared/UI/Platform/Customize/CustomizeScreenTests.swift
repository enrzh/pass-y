// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import BitwardenSdk
import SnapshotTesting
import SwiftUI
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - CustomizeScreenSnapshotTests

/// Customize: the screen itself and the vault home in three configurations (defaults, filled cards with a folder
/// card, types as folder rows with a folder card and hidden sections). Light and dark, rendered in a key window.
class CustomizeScreenSnapshotTests: BitwardenTestCase {
    // MARK: Helpers

    @MainActor
    private func snap(_ view: some View, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        assertSnapshots(
            of: view,
            as: [
                "portrait": .portrait(drawHierarchyInKeyWindow: true),
                "portraitDark": .portraitDark(drawHierarchyInKeyWindow: true),
            ],
            file: file,
            testName: testName,
            line: line,
        )
    }

    /// A vault home with tiles, favourites, folders and items without a folder.
    @MainActor
    private func home(_ preferences: PassYLayoutPreferences) -> some View {
        let tiles: [VaultListItem] = [
            VaultListItem(id: "Types.VerificationCodes", itemType: .group(.totp, 2)),
            VaultListItem(id: "Types.Logins", itemType: .group(.login, 12)),
            VaultListItem(id: "Types.Cards", itemType: .group(.card, 1)),
            VaultListItem(id: "Types.Identities", itemType: .group(.identity, 0)),
            VaultListItem(id: "Types.SecureNotes", itemType: .group(.secureNote, 3)),
            VaultListItem(id: "Types.SSHKeys", itemType: .group(.sshKey, 0)),
            VaultListItem(id: "Archive", itemType: .group(.archive, 0)),
            VaultListItem(id: "Trash", itemType: .group(.trash, 1)),
        ]
        let favorites = [
            VaultListItem.fixture(cipherListView: .fixture(
                id: "1",
                login: .fixture(username: "octo@example.test"),
                name: "GitHub",
                subtitle: "octo@example.test",
                favorite: true,
                attachments: 1,
            )),
        ]
        let folders = [
            VaultListItem(id: "f1", itemType: .group(.folder(id: "f1", name: "Work"), 4)),
            VaultListItem(id: "f2", itemType: .group(.folder(id: "f2", name: "Family"), 2)),
        ]
        let noFolder = [
            VaultListItem.fixture(cipherListView: .fixture(
                id: "2",
                login: .fixture(username: "me@example.test"),
                name: "Bank",
                subtitle: "me@example.test",
            )),
            VaultListItem.fixture(cipherListView: .fixture(id: "3", name: "Wi-Fi", type: .secureNote)),
        ]
        let state = VaultListState(loadingState: .data([
            VaultListSection(id: "TOTP", items: [tiles[0]], name: "TOTP"),
            VaultListSection(id: "Favorites", items: favorites, name: Localizations.favorites),
            VaultListSection(id: "Types", items: Array(tiles[1 ... 5]), name: Localizations.types),
            VaultListSection(id: "Folders", items: folders, name: Localizations.myFolders),
            VaultListSection(id: "NoFolder", items: noFolder, name: Localizations.folderNone),
            VaultListSection(id: "HiddenItems", items: Array(tiles[6...]), name: Localizations.hiddenItems),
        ]))
        let processor = MockProcessor<VaultListState, VaultListAction, VaultListEffect>(state: state)
        return NavigationView {
            VaultListView(
                store: Store(processor: processor),
                timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
                layoutStore: PassYLayoutStore(appSettingsStore: nil, initial: preferences),
            )
        }
    }

    // MARK: Tests

    /// The Customize screen at the defaults (preview, card colours, card switches with a folder).
    @MainActor
    func test_snapshot_customize() {
        let subject = CustomizeView(
            layout: PassYLayoutStore(appSettingsStore: nil),
            webIcons: PassYWebIconsSetting(read: { true }, write: { _ in }),
            folders: PassYCustomizeFolders(elements: [.init(id: "folder:f1", name: "Work")]),
        )
        snap(NavigationView { subject })
    }

    /// The home with the default preferences (today's look).
    @MainActor
    func test_snapshot_home_default() {
        snap(home(.default))
    }

    /// The home with filled cards ("Vollfarbig"): the whole card in the type colour, white content; the folder
    /// "Work" as a card.
    @MainActor
    func test_snapshot_home_filled() {
        var preferences = PassYLayoutPreferences.default
        preferences.home.cardColors = .filled
        preferences.home.folderCards = ["folder:f1"]
        snap(home(preferences))
    }

    /// The home with Archive and Trash as folder rows (Types section), the folder "Work" as a card in second place,
    /// no favourites, No folder first, rows without user names.
    @MainActor
    func test_snapshot_home_rowsAndFolderCards() {
        var preferences = PassYLayoutPreferences.default
        preferences.home.tileRows = ["archive", "trash"]
        preferences.home.folderCards = ["folder:f1"]
        preferences.home.tileOrder = ["totp", "folder:f1"]
        preferences.home.hiddenSections = ["Favorites"]
        preferences.home.sectionOrder = ["NoFolder", "Folders"]
        preferences.rows.showsSubtitle = false
        snap(home(preferences))
    }
}
