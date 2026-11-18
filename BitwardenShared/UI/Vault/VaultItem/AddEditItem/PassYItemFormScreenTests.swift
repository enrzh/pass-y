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

/// ui-r7: server-free renders (light and dark) of the add and edit forms of every item type, so the Apple-style rows
/// can be checked without a Vaultwarden server. The references in `__Snapshots__/PassYItemFormScreenTests/` are
/// copied to `Docs/screenshots/ui-r7/render/`. A key-window render is needed for `Form`s; very tall accessibility
/// sizes are covered by the UI tests.
class PassYItemFormSnapshotTests: BitwardenTestCase {
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

    /// An add form of the given type, with a name and a few values so the right-aligned value column is visible.
    @MainActor
    private func addForm(_ type: BitwardenShared.CipherType, reveal: Bool = false) -> some View {
        let processor = MockProcessor<AddEditItemState, AddEditItemAction, AddEditItemEffect>(
            state: CipherItemState(hasPremium: true),
        )
        processor.state.ownershipOptions = [.personal(displayName: "user@example.test")]
        processor.state.type = type
        processor.state.name = "Example"
        if type == .login {
            processor.state.loginState.username = "me@example.test"
            processor.state.loginState.password = "x1y2z3"
            processor.state.loginState.isPasswordVisible = reveal
        }
        return AddEditItemView(store: Store(processor: processor)).navStackWrapped
    }

    /// An edit form for an existing cipher.
    @MainActor
    private func editForm(_ cipher: CipherView, reveal: Bool = false) -> some View {
        let state = CipherItemState(existing: cipher, hasPremium: true)!
        let processor = MockProcessor<AddEditItemState, AddEditItemAction, AddEditItemEffect>(state: state)
        processor.state.ownershipOptions = [.personal(displayName: "user@example.test")]
        processor.state.loginState.isPasswordVisible = reveal
        return AddEditItemView(store: Store(processor: processor)).navStackWrapped
    }

    // MARK: Add

    @MainActor func test_snapshot_addLogin() { snap(addForm(.login)) }
    @MainActor func test_snapshot_addLoginRevealed() { snap(addForm(.login, reveal: true)) }
    @MainActor func test_snapshot_addCard() { snap(addForm(.card)) }
    @MainActor func test_snapshot_addIdentity() { snap(addForm(.identity)) }
    @MainActor func test_snapshot_addSecureNote() { snap(addForm(.secureNote)) }
    @MainActor func test_snapshot_addSSHKey() { snap(addForm(.sshKey)) }
    @MainActor func test_snapshot_addBankAccount() { snap(addForm(.bankAccount)) }
    @MainActor func test_snapshot_addPassport() { snap(addForm(.passport)) }
    @MainActor func test_snapshot_addDriversLicense() { snap(addForm(.driversLicense)) }

    // MARK: Edit

    @MainActor
    func test_snapshot_editLogin() {
        snap(editForm(.loginFixture(
            login: .fixture(password: "x1y2z3", username: "me@example.test"),
            name: "A fairly long item name that must not be clipped by a label",
        )))
    }

    @MainActor
    func test_snapshot_editLoginRevealed() {
        snap(editForm(
            .loginFixture(login: .fixture(password: "x1y2z3", username: "me@example.test"), name: "Example"),
            reveal: true,
        ))
    }

    @MainActor func test_snapshot_editCard() { snap(editForm(.cardFixture())) }
    @MainActor func test_snapshot_editIdentity() {
        snap(editForm(.fixture(
            identity: .fixture(firstName: "Jane", lastName: "Doe", email: "jane@example.test"),
            name: "Identity",
            type: .identity,
        )))
    }
    @MainActor func test_snapshot_editSecureNote() {
        snap(editForm(.fixture(name: "Note", notes: "Some secret text", secureNote: SecureNoteView(type: .generic), type: .secureNote)))
    }
    @MainActor func test_snapshot_editSSHKey() {
        snap(editForm(.fixture(name: "Server key", sshKey: .fixture(), type: .sshKey)))
    }
    @MainActor func test_snapshot_editBankAccount() { snap(editForm(.bankAccountFixture())) }
    @MainActor func test_snapshot_editPassport() { snap(editForm(.passportFixture())) }
    @MainActor func test_snapshot_editDriversLicense() { snap(editForm(.driversLicenseFixture())) }

    // MARK: Update / remove master password

    @MainActor
    func test_snapshot_updateMasterPassword() {
        let processor = MockProcessor<UpdateMasterPasswordState, UpdateMasterPasswordAction, UpdateMasterPasswordEffect>(
            state: UpdateMasterPasswordState(),
        )
        processor.state.masterPassword = "password123"
        processor.state.masterPasswordRetype = "password123"
        processor.state.masterPasswordHint = "hint hint"
        snap(UpdateMasterPasswordView(store: Store(processor: processor)).navStackWrapped)
    }

    @MainActor
    func test_snapshot_removeMasterPassword() {
        let processor = MockProcessor<RemoveMasterPasswordState, RemoveMasterPasswordAction, RemoveMasterPasswordEffect>(
            state: RemoveMasterPasswordState(
                masterPassword: "password",
                organizationName: "Example Org",
                organizationId: "Mock-Id",
                keyConnectorUrl: "www.example.com",
            ),
        )
        snap(RemoveMasterPasswordView(store: Store(processor: processor)).navStackWrapped)
    }
}
