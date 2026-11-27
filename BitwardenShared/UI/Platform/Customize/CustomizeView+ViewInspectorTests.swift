// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - CustomizeViewTests

class CustomizeViewTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var layout: PassYLayoutStore!
    var storedWebIcons: [Bool] = []
    var subject: CustomizeView!

    // MARK: Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()
        appSettingsStore = MockAppSettingsStore()
        layout = PassYLayoutStore(appSettingsStore: appSettingsStore)
        storedWebIcons = []
        subject = CustomizeView(
            layout: layout,
            webIcons: PassYWebIconsSetting(isOn: true, read: { true }, write: { [weak self] in self?.storedWebIcons.append($0) }),
            folders: PassYCustomizeFolders(elements: [.init(id: "folder:f1", name: "Work")]),
        )
    }

    override func tearDown() {
        super.tearDown()
        appSettingsStore = nil
        layout = nil
        subject = nil
    }

    // MARK: Tests

    /// Every type and folder has a card switch: off turns a type into a folder row, on turns a folder into a card
    /// (and persists it).
    @MainActor
    func test_cardToggles_switchTypesAndFolders() throws {
        for id in PassYLayoutPreferences.knownTiles + ["folder:f1"] {
            XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_\(id)"))
        }
        let sshKey = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_sshKey").toggle()
        XCTAssertTrue(try sshKey.isOn())
        try sshKey.tap()
        XCTAssertEqual(layout.home.tileRows, ["sshKey"])
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.tileRows, ["sshKey"])
        let folder = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_folder:f1").toggle()
        XCTAssertFalse(try folder.isOn())
        try folder.tap()
        XCTAssertEqual(layout.home.folderCards, ["folder:f1"])
    }

    /// Dragging an element (onMove) stores the new order, folders included.
    @MainActor
    func test_elements_onMove_reorders() throws {
        let elements = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_totp")
            .find(ViewType.ForEach.self, relation: .parent)
        try elements.callOnMove(IndexSet(integer: 0), 2)
        XCTAssertEqual(Array(layout.preferences.orderedTiles.prefix(2)), ["login", "totp"])
        let last = PassYLayoutPreferences.knownTiles.count
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_totp")
            .find(ViewType.ForEach.self, relation: .parent)
            .callOnMove(IndexSet(integer: last), 0)
        XCTAssertEqual(layout.preferences.orderedElements(folders: ["folder:f1"]).first, "folder:f1")
    }

    /// Sections: show/hide, collapsed when opened, order.
    @MainActor
    func test_sections_toggleCollapseAndMove() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeSectionToggle_Favorites").toggle().tap()
        XCTAssertEqual(layout.home.hiddenSections, ["Favorites"])
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeSectionCollapsed_Folders").toggle().tap()
        XCTAssertEqual(layout.home.collapsedSections, ["Folders"])
        let sections = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeSectionToggle_NoFolder")
            .find(ViewType.ForEach.self, relation: .parent)
        try sections.callOnMove(IndexSet(integer: 3), 0)
        XCTAssertEqual(layout.preferences.orderedSections.first, "NoFolder")
    }

    /// The card colours picker (Colorful / Filled); no layout or density option any more.
    @MainActor
    func test_cardColorsPicker() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeCardColorsPicker").picker()
            .select(value: PassYLayoutPreferences.CardColors.filled)
        XCTAssertEqual(layout.home.cardColors, .filled)
        for removed in ["CustomizeTileLayoutPicker", "CustomizeDensityPicker", "CustomizeTileColorsPicker",
                        "CustomizeCountdownRingToggle", "CustomizeCountdownSecondsToggle"] {
            XCTAssertThrowsError(try subject.inspect().find(viewWithAccessibilityIdentifier: removed), removed)
        }
    }

    /// The row and code switches.
    @MainActor
    func test_rowAndCodeToggles() throws {
        let expectations: [(String, (PassYLayoutStore) -> Bool)] = [
            ("CustomizeShowSubtitleToggle", { $0.rows.showsSubtitle }),
            ("CustomizeShowIconToggle", { $0.rows.showsIcon }),
            ("CustomizeFavoriteBadgeToggle", { $0.rows.showsFavoriteBadge }),
            ("CustomizeSharedBadgeToggle", { $0.rows.showsSharedBadge }),
            ("CustomizeAttachmentBadgeToggle", { $0.rows.showsAttachmentBadge }),
            ("CustomizeGroupDigitsToggle", { $0.codes.groupsDigits }),
        ]
        for (identifier, value) in expectations {
            XCTAssertTrue(value(layout), identifier)
            try subject.inspect().find(viewWithAccessibilityIdentifier: identifier).toggle().tap()
            XCTAssertFalse(value(layout), identifier)
        }
    }

    /// The website icons switch writes the existing setting (no second preference).
    @MainActor
    func test_webIconsToggle_writesExistingSetting() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeShowWebIconsToggle").toggle().tap()
        waitFor { self.storedWebIcons == [false] }
        XCTAssertEqual(layout.preferences, .default, "not part of the layout preferences")
    }

    /// Reset to defaults is disabled at the defaults and restores them.
    @MainActor
    func test_reset() throws {
        XCTAssertTrue(try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeResetButton").isDisabled())
        layout.home.tileRows = ["trash"]
        layout.home.cardColors = .filled
        let button = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeResetButton").button()
        XCTAssertFalse(button.isDisabled())
        try button.tap()
        XCTAssertTrue(layout.isDefault)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences, .default)
    }

    /// The Settings row opens Customize; the avatar menu has no Customize entry any more (the home's long-press
    /// menus have it).
    @MainActor
    func test_entryPoints() throws {
        let processor = MockProcessor<SettingsState, SettingsAction, SettingsEffect>(state: SettingsState())
        let settings = SettingsView(store: Store(processor: processor))
        try settings.inspect().find(button: Localizations.customize).tap()
        XCTAssertEqual(processor.dispatchedActions.last, .customizePressed)

        let model = PassYShellModel.shared
        model.profileMenu = PassYProfileMenuSource(
            activeProfile: nil,
            canLock: false,
            lock: { _ in },
            pendingRequests: {},
            serverURL: "",
            showsPlaceholder: true,
            sync: {},
        )
        XCTAssertThrowsError(try PassYAvatarMenu().inspect().find(viewWithAccessibilityIdentifier: "ProfileMenuCustomizeButton"))
        XCTAssertNoThrow(try PassYAvatarMenu().inspect().find(viewWithAccessibilityIdentifier: "ProfileMenuSyncButton"))
        model.profileMenu = nil
    }

    /// The folders reader loads the folders when the screen appears.
    @MainActor
    func test_folders_load() async {
        let folders = PassYCustomizeFolders(read: { [.init(id: "folder:a", name: "A")] })
        await folders.load()
        XCTAssertEqual(folders.ids, ["folder:a"])
        XCTAssertEqual(folders.name(of: "folder:a"), "A")
        XCTAssertNil(folders.name(of: "folder:b"))
    }
}
