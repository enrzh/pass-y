// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

/// The avatar menu, the account row of Settings, no watch option (formerly `PassYUiR9ViewInspectorTests`).
class PassYAvatarMenuViewInspectorTests: BitwardenTestCase {
    // MARK: Avatar menu

    @MainActor
    private func makeMenuModel(pending: @escaping () -> Void = {}) -> PassYShellModel {
        let model = PassYShellModel.shared
        model.availableDestinations = PassYDestination.allCases
        model.profileMenu = PassYProfileMenuSource(
            activeProfile: nil,
            canLock: false,
            lock: { _ in },
            pendingRequests: pending,
            serverURL: "https://vault.example.com",
            showsPlaceholder: true,
            sync: {},
        )
        return model
    }

    /// The menu has Send, Generator, Settings, pending login requests and sync; no Vault, no accounts, no Add account.
    @MainActor
    func test_avatarMenu_entries() throws {
        _ = makeMenuModel()
        let menu = try PassYAvatarMenu().inspect().find(ViewType.Menu.self)
        XCTAssertNoThrow(try menu.find(button: Localizations.send))
        XCTAssertNoThrow(try menu.find(button: Localizations.generator))
        XCTAssertNoThrow(try menu.find(button: Localizations.settings))
        XCTAssertNoThrow(try menu.find(button: Localizations.pendingLogInRequests))
        XCTAssertNoThrow(try menu.find(button: Localizations.syncNow))
        XCTAssertThrowsError(try menu.find(button: Localizations.myVault), "no Vault entry")
        XCTAssertThrowsError(try menu.find(button: Localizations.addAccount), "no Add account")
        XCTAssertThrowsError(try menu.find(text: "Pass-Y"), "no app name")
    }

    /// The connected server is shown at the top of the menu.
    @MainActor
    func test_avatarMenu_showsServerURL() throws {
        _ = makeMenuModel()
        let menu = try PassYAvatarMenu().inspect().find(ViewType.Menu.self)
        XCTAssertNoThrow(try menu.find(text: "https://vault.example.com"))
    }

    /// Pending login requests is an action of the menu.
    @MainActor
    func test_avatarMenu_pendingRequestsTap() throws {
        var tapped = false
        _ = makeMenuModel { tapped = true }
        let menu = try PassYAvatarMenu().inspect().find(ViewType.Menu.self)
        try menu.find(button: Localizations.pendingLogInRequests).tap()
        XCTAssertTrue(tapped)
    }

    // MARK: Settings account row

    @MainActor
    private func makeSettings(serverURL: String) -> (SettingsView, MockProcessor<SettingsState, SettingsAction, SettingsEffect>) {
        var state = SettingsState()
        state.profileState = .singleAccount
        state.serverURL = serverURL
        let processor = MockProcessor<SettingsState, SettingsAction, SettingsEffect>(state: state)
        return (SettingsView(store: Store(processor: processor)), processor)
    }

    /// The account row shows the server URL (not "Pass-Y") and the menu offers Add account.
    @MainActor
    func test_settings_accountRow_serverAndAddAccount() throws {
        let (subject, processor) = makeSettings(serverURL: "https://vault.example.com")
        XCTAssertNoThrow(try subject.inspect().find(text: "https://vault.example.com"))
        XCTAssertThrowsError(try subject.inspect().find(text: "Pass-Y"))
        let add = try subject.inspect().find(button: Localizations.addAccount)
        try add.tap()
        XCTAssertEqual(processor.dispatchedActions.last, .addAccountPressed)
    }
}
