import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

class SettingsProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var authRepository: MockAuthRepository!
    var coordinator: MockCoordinator<SettingsRoute, SettingsEvent>!
    var delegate: MockSettingsProcessorDelegate!
    var errorReporter: MockErrorReporter!
    var subject: SettingsProcessor!
    var stateService: MockStateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()

        authRepository = MockAuthRepository()
        coordinator = MockCoordinator()
        delegate = MockSettingsProcessorDelegate()
        errorReporter = MockErrorReporter()
        stateService = MockStateService()

        setUpSubject()
    }

    override func tearDown() {
        super.tearDown()

        authRepository = nil
        coordinator = nil
        delegate = nil
        errorReporter = nil
        subject = nil
        stateService = nil
    }

    @MainActor
    func setUpSubject(presentationMode: SettingsPresentationMode = .tab) {
        subject = SettingsProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            delegate: delegate,
            services: ServiceContainer.withMocks(
                authRepository: authRepository,
                errorReporter: errorReporter,
                stateService: stateService,
            ),
            state: SettingsState(presentationMode: presentationMode),
        )
    }

    // MARK: Tests

    /// `init()` does not subscribe to the badge publisher when the presentation mode is `.preLogin`.
    @MainActor
    func test_init_preLogin_doesNotSubscribeToBadgePublisher() async {
        setUpSubject(presentationMode: .preLogin)
        XCTAssertNil(subject.badgeUpdateTask)
    }

    /// `init()` subscribes to the badge publisher and notifies the delegate to update the badge
    /// count when it changes.
    @MainActor
    func test_init_subscribesToBadgePublisher() async throws {
        stateService.activeAccount = .fixture()
        setUpSubject()
        XCTAssertNotNil(subject.badgeUpdateTask)

        var badgeState = SettingsBadgeState.fixture(badgeValue: "1", vaultUnlockSetupProgress: .setUpLater)
        stateService.settingsBadgeSubject.send(badgeState)
        try await waitForAsync { self.delegate.badgeValue == "1" }
        XCTAssertEqual(delegate.badgeValue, "1")
        XCTAssertEqual(subject.state.badgeState, badgeState)

        badgeState = SettingsBadgeState.fixture(
            autofillSetupProgress: .setUpLater,
            badgeValue: "2",
            vaultUnlockSetupProgress: .setUpLater,
        )
        stateService.settingsBadgeSubject.send(badgeState)
        try await waitForAsync { self.delegate.badgeValue == "2" }
        XCTAssertEqual(delegate.badgeValue, "2")
        XCTAssertEqual(subject.state.badgeState, badgeState)

        badgeState = SettingsBadgeState.fixture(badgeValue: nil)
        stateService.settingsBadgeSubject.send(badgeState)
        try await waitForAsync { self.delegate.badgeValue == nil }
        XCTAssertNil(delegate.badgeValue)
        XCTAssertEqual(subject.state.badgeState, badgeState)
    }

    /// `init()` subscribes to the badge publisher and logs an error if one occurs.
    @MainActor
    func test_init_subscribesToBadgePublisher_error() async throws {
        setUpSubject()

        stateService.settingsBadgeSubject.send(SettingsBadgeState.fixture(badgeValue: "1"))
        try await waitForAsync { !self.errorReporter.errors.isEmpty }

        XCTAssertEqual(errorReporter.errors as? [StateServiceError], [.noActiveAccount])
    }

    /// Receiving `.aboutPressed` navigates to the about screen.
    @MainActor
    func test_receive_aboutPressed() {
        subject.receive(.aboutPressed)

        XCTAssertEqual(coordinator.routes.last, .about)
    }

    /// Receiving `.accountSecurityPressed` navigates to the account security screen.
    @MainActor
    func test_receive_accountSecurityPressed() {
        subject.receive(.accountSecurityPressed)

        XCTAssertEqual(coordinator.routes.last, .accountSecurity)
    }

    /// Receiving `.appearancePressed` navigates to the appearance screen.
    @MainActor
    func test_receive_appearancePressed() {
        subject.receive(.appearancePressed)

        XCTAssertEqual(coordinator.routes.last, .appearance)
    }

    /// Receiving `.autoFillPressed` navigates to the auto-fill screen.
    @MainActor
    func test_receive_autoFillPressed() {
        subject.receive(.autoFillPressed)

        XCTAssertEqual(coordinator.routes.last, .autoFill)
    }

    /// Receiving `.dismiss` has the coordinator dismiss the view.
    @MainActor
    func test_receive_dismiss() {
        subject.receive(.dismiss)

        XCTAssertEqual(coordinator.routes.last, .dismiss())
    }

    /// Receiving `.otherPressed` navigates to the other screen.
    @MainActor
    func test_receive_otherPressed() {
        subject.receive(.otherPressed)

        XCTAssertEqual(coordinator.routes.last, .other)
    }

    /// Receiving `.vaultPressed` navigates to the vault settings screen.
    @MainActor
    func test_receive_vaultPressed() {
        subject.receive(.vaultPressed)

        XCTAssertEqual(coordinator.routes.last, .vault)
    }

    /// `perform(.appeared)` does nothing in pre-login presentation mode.
    @MainActor
    func test_perform_appeared_preLogin_doesNothing() async {
        setUpSubject(presentationMode: .preLogin)
        await subject.perform(.appeared)
        XCTAssertFalse(subject.state.hasPremium)
        XCTAssertFalse(subject.state.showPlanRow)
    }

    /// `perform(.loadProfile)` loads the accounts for the account row at the top.
    @MainActor
    func test_perform_loadProfile() async {
        authRepository.profileSwitcherState = .dualAccounts
        await subject.perform(.loadProfile)
        XCTAssertEqual(subject.state.profileState.accounts, ProfileSwitcherState.dualAccounts.accounts)
        XCTAssertEqual(subject.state.profileState.activeAccountId, ProfileSwitcherState.dualAccounts.activeAccountId)
    }

    /// `receive(.lockPressed)` locks the active vault.
    @MainActor
    func test_receive_lockPressed() async throws {
        subject.receive(.lockPressed)
        try await waitForAsync { !self.coordinator.events.isEmpty }
        XCTAssertEqual(coordinator.events.last, .authAction(.lockVault(userId: nil, isManuallyLocking: true)))
    }

    /// `receive(.logoutPressed)` asks for confirmation and then logs the user out.
    @MainActor
    func test_receive_logoutPressed() async throws {
        subject.receive(.logoutPressed)
        let alert = try XCTUnwrap(coordinator.alertShown.last)
        XCTAssertEqual(alert.alertActions[0].title, Localizations.yes)
        try await alert.tapAction(title: Localizations.yes)
        XCTAssertEqual(coordinator.events.last, .authAction(.logout(userId: nil, userInitiated: true)))
    }

    /// `receive(.switchAccountPressed)` switches to the chosen account.
    @MainActor
    func test_receive_switchAccountPressed() async throws {
        let account = ProfileSwitcherState.dualAccounts.accounts[1]
        subject.receive(.switchAccountPressed(account))
        try await waitForAsync { !self.coordinator.events.isEmpty }
        XCTAssertEqual(
            coordinator.events.last,
            .authAction(.switchAccount(isAutomatic: false, userId: account.userId, authCompletionRoute: nil)),
        )
    }

    /// `receive(.clearUrl)` clears the URL from state.
    @MainActor
    func test_receive_clearUrl() {
        subject.state.url = .example
        subject.receive(.clearUrl)

        XCTAssertNil(subject.state.url)
    }
}

class MockSettingsProcessorDelegate: SettingsProcessorDelegate {
    var badgeValue: String?

    func updateSettingsTabBadge(_ badgeValue: String?) {
        self.badgeValue = badgeValue
    }
}
