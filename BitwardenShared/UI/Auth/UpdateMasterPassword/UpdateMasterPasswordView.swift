import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - UpdateMasterPasswordView

/// A view that forces the user to update their master password.
///
struct UpdateMasterPasswordView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<UpdateMasterPasswordState, UpdateMasterPasswordAction, UpdateMasterPasswordEffect>

    var body: some View {
        Form {
            if store.state.forcePasswordResetReason != nil {
                Section {
                    Text(store.state.updateMasterPasswordWarning)
                        .font(.subheadline)

                    if let policy = store.state.masterPasswordPolicy,
                       policy.isInEffect,
                       let policySummary = policy.policySummary {
                        Text(policySummary)
                            .font(.subheadline)
                    }
                }
            }

            if store.state.requireCurrentPassword {
                Section {
                    PassYPasswordField(
                        Localizations.currentMasterPasswordRequired,
                        text: store.binding(
                            get: \.currentMasterPassword,
                            send: UpdateMasterPasswordAction.currentMasterPasswordChanged,
                        ),
                        isRevealed: store.state.isCurrentMasterPasswordRevealed,
                        fieldIdentifier: "MasterPasswordField",
                        toggleIdentifier: "MasterPasswordVisibilityToggle",
                    ) { store.send(.revealCurrentMasterPasswordFieldPressed($0)) }
                }
            }

            Section {
                PassYPasswordField(
                    Localizations.newMasterPasswordRequired,
                    text: store.binding(
                        get: \.masterPassword,
                        send: UpdateMasterPasswordAction.masterPasswordChanged,
                    ),
                    isRevealed: store.state.isMasterPasswordRevealed,
                    contentType: .newPassword,
                    fieldIdentifier: "NewPasswordField",
                    toggleIdentifier: "NewPasswordVisibilityToggle",
                ) { store.send(.revealMasterPasswordFieldPressed($0)) }

                PasswordStrengthIndicator(
                    passwordStrengthScore: store.state.passwordStrengthScore,
                    passwordTextCount: store.state.masterPassword.count,
                    requiredTextCount: store.state.requiredPasswordCount,
                )

                PassYPasswordField(
                    Localizations.retypeNewMasterPasswordRequired,
                    text: store.binding(
                        get: \.masterPasswordRetype,
                        send: UpdateMasterPasswordAction.masterPasswordRetypeChanged,
                    ),
                    isRevealed: store.state.isMasterPasswordRetypeRevealed,
                    contentType: .newPassword,
                    fieldIdentifier: "RetypePasswordField",
                    toggleIdentifier: "RetypePasswordVisibilityToggle",
                ) { store.send(.revealMasterPasswordRetypeFieldPressed($0)) }
            }

            Section {
                TextField(
                    Localizations.newMasterPasswordHint,
                    text: store.binding(
                        get: \.masterPasswordHint,
                        send: UpdateMasterPasswordAction.masterPasswordHintChanged,
                    ),
                )
                .accessibilityIdentifier("MasterPasswordHintLabel")
            } footer: {
                PassYFooterText(
                    Localizations.bitwardenCannotResetALostOrForgottenMasterPassword,
                    link: Localizations.learnAboutWaysToPreventAccountLockout,
                    linkIdentifier: "PreventAccountLockButton",
                ) {
                    store.send(.preventAccountLockTapped)
                }
            }
        }
        .passYGroupedBackground()
        .navigationTitle(Localizations.updateMasterPassword)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                AsyncButton {
                    await store.perform(.logoutTapped)
                } label: {
                    // Widens the Liquid Glass background to match the prominent primary action button on the other
                    // side of the toolbar.
                    Text(Localizations.logOut)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.toolbar)
                .frame(minHeight: 44)
                .fixedSize()
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                primaryActionToolbarButton(Localizations.save) {
                    await store.perform(.saveTapped)
                }
                .accessibilityIdentifier("SaveButton")
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
        UpdateMasterPasswordView(
            store: Store(
                processor: StateProcessor(
                    state: UpdateMasterPasswordState(),
                ),
            ),
        )
    }
}
#endif
