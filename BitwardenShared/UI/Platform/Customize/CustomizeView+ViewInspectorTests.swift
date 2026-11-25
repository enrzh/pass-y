// swiftlint:disable:this file_name
import BitwardenKit
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
        )
    }

    override func tearDown() {
        super.tearDown()
        appSettingsStore = nil
        layout = nil
        subject = nil
    }

    // MARK: Tests

    /// Every tile has a show/hide switch; switching one off hides it from the home (and persists it).
    @MainActor
    func test_tileToggle_hidesTile() throws {
        for id in PassYLayoutPreferences.knownTiles {
            XCTAssertNoThrow(try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_\(id)"))
        }
        let toggle = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_sshKey").toggle()
        try toggle.tap()
        XCTAssertEqual(layout.home.hiddenTiles, ["sshKey"])
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences?.home.hiddenTiles, ["sshKey"])
    }

    /// Dragging a tile (onMove) stores the new order.
    @MainActor
    func test_tiles_onMove_reorders() throws {
        let tiles = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileToggle_totp")
            .find(ViewType.ForEach.self, relation: .parent)
        try tiles.callOnMove(IndexSet(integer: 0), 2)
        XCTAssertEqual(Array(layout.preferences.orderedTiles.prefix(2)), ["login", "totp"])
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
        try sections.callOnMove(IndexSet(integer: 2), 0)
        XCTAssertEqual(layout.preferences.orderedSections.first, "NoFolder")
    }

    /// The tile layout, density and tile colour pickers.
    @MainActor
    func test_pickers() throws {
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileLayoutPicker").picker()
            .select(value: PassYLayoutPreferences.TileLayout.list)
        XCTAssertEqual(layout.home.tileLayout, .list)
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeDensityPicker").picker()
            .select(value: PassYLayoutPreferences.Density.compact)
        XCTAssertEqual(layout.rows.density, .compact)
        try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeTileColorsPicker").picker()
            .select(value: PassYLayoutPreferences.TileColors.monochrome)
        XCTAssertEqual(layout.rows.tileColors, .monochrome)
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
            ("CustomizeCountdownRingToggle", { $0.codes.showsCountdownRing }),
            ("CustomizeCountdownSecondsToggle", { $0.codes.showsCountdownSeconds }),
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
        layout.home.hiddenTiles = ["trash"]
        layout.rows.density = .compact
        let button = try subject.inspect().find(viewWithAccessibilityIdentifier: "CustomizeResetButton").button()
        XCTAssertFalse(button.isDisabled())
        try button.tap()
        XCTAssertTrue(layout.isDefault)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences, .default)
    }

    /// The Settings row and the avatar menu entry open Customize.
    @MainActor
    func test_entryPoints() throws {
        let processor = MockProcessor<SettingsState, SettingsAction, SettingsEffect>(state: SettingsState())
        let settings = SettingsView(store: Store(processor: processor))
        try settings.inspect().find(button: Localizations.customize).tap()
        XCTAssertEqual(processor.dispatchedActions.last, .customizePressed)

        var customized = false
        let model = PassYShellModel.shared
        model.profileMenu = PassYProfileMenuSource(
            activeProfile: nil,
            canLock: false,
            lock: { _ in },
            pendingRequests: {},
            serverURL: "",
            showsPlaceholder: true,
            sync: {},
            customize: { customized = true },
        )
        try PassYAvatarMenu().inspect().find(button: Localizations.customizeHome).tap()
        XCTAssertTrue(customized)
        model.profileMenu = nil
    }
}
