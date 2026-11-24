import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - RemoveMasterPasswordView

/// A view that notifies the user that they need to remove their master password.
///
struct RemoveMasterPasswordView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<RemoveMasterPasswordState, RemoveMasterPasswordAction, RemoveMasterPasswordEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localizations.removeMasterPasswordConfirmDomain)
                        .foregroundStyle(.primary)
                    Text(Localizations.keyConnectorOrganization)
                        .foregroundStyle(.primary)
                    Text(store.state.organizationName)
                        .foregroundStyle(.secondary)
                    Text(Localizations.keyConnectorDomain)
                        .foregroundStyle(.primary)
                    Text(store.state.keyConnectorUrl)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
            }

            Section {
                BitwardenTextField(
                    title: Localizations.masterPassword,
                    text: store.binding(
                        get: \.masterPassword,
                        send: RemoveMasterPasswordAction.masterPasswordChanged,
                    ),
                    footer: nil,
                    accessibilityIdentifier: "MasterPasswordEntry",
                    passwordVisibilityAccessibilityId: "PasswordVisibilityToggle",
                    isPasswordAutoFocused: true,
                    isPasswordVisible: store.binding(
                        get: \.isMasterPasswordRevealed,
                        send: RemoveMasterPasswordAction.revealMasterPasswordFieldPressed,
                    ),
                )
                .textFieldConfiguration(.password)
                .submitLabel(.go)
                .onSubmit {
                    Task {
                        await store.perform(.continueFlow)
                    }
                }
            }

            Section {
                AsyncButton {
                    await store.perform(.continueFlow)
                } label: {
                    Text(Localizations.continue).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                AsyncButton {
                    await store.perform(.leaveOrganizationFlow)
                } label: {
                    Text(Localizations.leaveOrganization).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .nativeFormRows()
        .passYGroupedBackground()
        .navigationBar(title: Localizations.removeMasterPassword, titleDisplayMode: .inline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("RemoveMasterPassword") {
    RemoveMasterPasswordView(
        store: Store(
            processor: StateProcessor(
                state: RemoveMasterPasswordState(
                    masterPassword: "password",
                    organizationName: "Example Org",
                    organizationId: "Mock-Id",
                    keyConnectorUrl: "www.example.com",
                ),
            ),
        ),
    )
    .navStackWrapped
}
#endif
