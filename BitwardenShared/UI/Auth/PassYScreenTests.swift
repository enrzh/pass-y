// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import BitwardenSdk
import SnapshotTesting
import SwiftUI
import XCTest

@testable import BitwardenShared

/// ui-r5: enabled snapshot tests for the screens that the throwaway test account cannot reach in the UI tests
/// (login with device, set master password, two-factor email/recovery, PIN unlock, SSH key form). Light and dark (a key-window render is needed for lists;
/// it cannot render the very tall accessibility sizes, those are covered by the UI tests). The references in `__Snapshots__` are the screenshots in `Docs/screenshots/ui-r5`.
class PassYScreenSnapshotTests: BitwardenTestCase {
    @MainActor
    private func snap(_ view: some View, file: StaticString = #file, testName: String = #function, line: UInt = #line) {
        assertSnapshots(
            of: view,
            as: ["portrait": .portrait(drawHierarchyInKeyWindow: true), "portraitDark": .portraitDark(drawHierarchyInKeyWindow: true)],
            file: file,
            testName: testName,
            line: line,
        )
    }

    @MainActor
    func test_snapshot_loginWithDevice() {
        let processor = MockProcessor<LoginWithDeviceState, LoginWithDeviceAction, LoginWithDeviceEffect>(
            state: LoginWithDeviceState(fingerprintPhrase: "some-weird-long-text-thing-as-a-placeholder"),
        )
        let subject = LoginWithDeviceView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_setMasterPassword() {
        let processor = MockProcessor<SetMasterPasswordState, SetMasterPasswordAction, SetMasterPasswordEffect>(
            state: SetMasterPasswordState(organizationIdentifier: "ORG_ID"),
        )
        processor.state.masterPassword = "password123"
        processor.state.masterPasswordRetype = "password123"
        processor.state.masterPasswordHint = "hint hint"
        let subject = SetMasterPasswordView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_twoFactorEmail() {
        let processor = MockProcessor<TwoFactorAuthState, TwoFactorAuthAction, TwoFactorAuthEffect>(
            state: TwoFactorAuthState(displayEmail: "sh***@example.test"),
        )
        processor.state.authMethod = .email
        let subject = TwoFactorAuthView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_twoFactorRecoveryCode() {
        let processor = MockProcessor<TwoFactorAuthState, TwoFactorAuthAction, TwoFactorAuthEffect>(
            state: TwoFactorAuthState(displayEmail: "sh***@example.test"),
        )
        processor.state.authMethod = .recoveryCode
        let subject = TwoFactorAuthView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_pinUnlock() {
        let processor = MockProcessor<VaultUnlockState, VaultUnlockAction, VaultUnlockEffect>(
            state: VaultUnlockState(
                email: "user@example.test",
                profileSwitcherState: .init(accounts: [], activeAccountId: nil, allowLockAndLogout: false, isVisible: false),
                unlockMethod: .pin,
                webVaultHost: "example.test",
            ),
        )
        let subject = VaultUnlockView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_addSSHKey() {
        let processor = MockProcessor<AddEditItemState, AddEditItemAction, AddEditItemEffect>(
            state: CipherItemState(hasPremium: true),
        )
        processor.state.ownershipOptions = [.personal(displayName: "user@example.test")]
        processor.state.type = .sshKey
        processor.state.name = "Server key"
        let subject = AddEditItemView(store: Store(processor: processor))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_generatorInPlace() {
        var state = GeneratorState()
        state.generatedValue = "AK@N3zGAmeYvueGRjmGH2vA0^Aa3hw2g"
        state.presentationMode = .inPlace
        let subject = GeneratorView(store: Store(processor: StateProcessor(state: state)))
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_autofillTextToInsert() {
        let processor = MockProcessor<VaultAutofillListState, VaultAutofillListAction, VaultAutofillListEffect>(
            state: VaultAutofillListState(),
        )
        processor.state.isAutofillingTextToInsertList = true
        processor.state.loadingState = .data([
            VaultListSection(
                id: "Types",
                items: [
                    VaultListItem(id: "Logins", itemType: .group(.login, 240)),
                    VaultListItem(id: "Cards", itemType: .group(.card, 3)),
                    VaultListItem(id: "Identities", itemType: .group(.identity, 1)),
                    VaultListItem(id: "SSHKeys", itemType: .group(.sshKey, 2)),
                ],
                name: Localizations.types,
            ),
            VaultListSection(
                id: "Folders",
                items: [VaultListItem(id: "work", itemType: .group(.folder(id: "work", name: "Work"), 12))],
                name: Localizations.myFolders,
            ),
        ])
        let subject = VaultAutofillListView(
            store: Store(processor: processor),
            timeProvider: MockTimeProvider(.mockTime(Date(timeIntervalSince1970: 1_700_000_000))),
        )
        snap(subject.navStackWrapped)
    }

    @MainActor
    func test_snapshot_itemSelectionEmpty() {
        let state = VaultItemSelectionState(iconBaseURL: nil, totpKeyModel: .fixtureExample)
        let subject = VaultItemSelectionView(store: Store(processor: StateProcessor(state: state)))
        snap(subject.navStackWrapped)
    }
}
