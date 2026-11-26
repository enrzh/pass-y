import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SetMasterPasswordView

/// A view that forces the user to set their master password.
///
struct SetMasterPasswordView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<SetMasterPasswordState, SetMasterPasswordAction, SetMasterPasswordEffect>

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(title: Localizations.chooseYourMasterPassword, message: store.state.explanationText)
            }
            .passYPlainListRow()

            if store.state.resetPasswordAutoEnroll {
                Section {
                    Text(Localizations.resetPasswordAutoEnrollInviteWarning)
                        .font(.subheadline)
                }
            }

            if let policy = store.state.masterPasswordPolicy,
               policy.isInEffect,
               let policySummary = policy.policySummary {
                Section {
                    Text(policySummary)
                        .font(.subheadline)
                }
            }

            Section {
                PassYPasswordField(
                    Localizations.masterPasswordRequired,
                    text: store.binding(
                        get: \.masterPassword,
                        send: SetMasterPasswordAction.masterPasswordChanged,
                    ),
                    isRevealed: store.state.isMasterPasswordRevealed,
                    contentType: .newPassword,
                    fieldIdentifier: "NewPasswordField",
                    toggleIdentifier: "NewPasswordVisibilityToggle",
                ) { store.send(.revealMasterPasswordFieldPressed($0)) }

                PassYPasswordField(
                    Localizations.retypeMasterPasswordRequired,
                    text: store.binding(
                        get: \.masterPasswordRetype,
                        send: SetMasterPasswordAction.masterPasswordRetypeChanged,
                    ),
                    isRevealed: store.state.isMasterPasswordRevealed,
                    contentType: .newPassword,
                    fieldIdentifier: "RetypePasswordField",
                    toggleIdentifier: "RetypePasswordVisibilityToggle",
                ) { store.send(.revealMasterPasswordFieldPressed($0)) }
            } footer: {
                PassYFooterText(Localizations.theMasterPasswordIsThePasswordYouUseToAccessYourVault)
            }

            Section {
                TextField(
                    Localizations.masterPasswordHint,
                    text: store.binding(
                        get: \.masterPasswordHint,
                        send: SetMasterPasswordAction.masterPasswordHintChanged,
                    ),
                )
                .accessibilityIdentifier("MasterPasswordHintLabel")
            } footer: {
                PassYFooterText(
                    Localizations.bitwardenCannotResetALostOrForgottenMasterPassword,
                    link: Localizations.learnAboutWaysToPreventAccountLockout,
                ) {
                    store.send(.preventAccountLockTapped)
                }
            }
        }
        .passYGroupedBackground()
        .navigationTitle(Localizations.setMasterPassword)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !store.state.isPrivilegeElevation {
                    cancelToolbarButton {
                        Task {
                            await store.perform(.cancelPressed)
                        }
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                primaryActionToolbarButton(Localizations.save) {
                    Task {
                        await store.perform(.saveTapped)
                    }
                }
                .accessibilityIdentifier("SubmitButton")
            }
        }
        .task {
            await store.perform(.appeared)
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    NavigationView {
        SetMasterPasswordView(
            store: Store(
                processor: StateProcessor(
                    state: SetMasterPasswordState(organizationIdentifier: ""),
                ),
            ),
        )
    }
}
#endif
