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
/// (login with device, set master password, two-factor email/recovery, PIN unlock, SSH key form). Light, dark and the
/// largest accessibility text size. The references in `__Snapshots__` are the screenshots in `Docs/screenshots/ui-r5`.
class PassYScreenSnapshotTests: BitwardenTestCase {
    private let strategies: [String: Snapshotting<UIViewController, UIImage>] = [
        "portrait": .portrait(),
        "portraitDark": .portraitDark(),
        "tallPortraitAX5": .tallPortraitAX5(),
    ]

    @MainActor
    func test_snapshot_loginWithDevice() {
        let processor = MockProcessor<LoginWithDeviceState, LoginWithDeviceAction, LoginWithDeviceEffect>(
            state: LoginWithDeviceState(fingerprintPhrase: "some-weird-long-text-thing-as-a-placeholder"),
        )
        let subject = LoginWithDeviceView(store: Store(processor: processor))
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
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
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
    }

    @MainActor
    func test_snapshot_twoFactorEmail() {
        let processor = MockProcessor<TwoFactorAuthState, TwoFactorAuthAction, TwoFactorAuthEffect>(
            state: TwoFactorAuthState(displayEmail: "sh***@example.test"),
        )
        processor.state.authMethod = .email
        let subject = TwoFactorAuthView(store: Store(processor: processor))
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
    }

    @MainActor
    func test_snapshot_twoFactorRecoveryCode() {
        let processor = MockProcessor<TwoFactorAuthState, TwoFactorAuthAction, TwoFactorAuthEffect>(
            state: TwoFactorAuthState(displayEmail: "sh***@example.test"),
        )
        processor.state.authMethod = .recoveryCode
        let subject = TwoFactorAuthView(store: Store(processor: processor))
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
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
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
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
        assertSnapshots(of: subject.navStackWrapped, as: strategies)
    }
}
