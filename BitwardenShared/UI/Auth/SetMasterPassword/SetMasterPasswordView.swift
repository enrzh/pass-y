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
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                    Text(Localizations.chooseYourMasterPassword)
                        .font(.title3.weight(.semibold))
                    Text(store.state.explanationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

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
                BitwardenTextField(
                    title: Localizations.masterPasswordRequired,
                    text: store.binding(
                        get: \.masterPassword,
                        send: SetMasterPasswordAction.masterPasswordChanged,
                    ),
                    footer: Localizations.theMasterPasswordIsThePasswordYouUseToAccessYourVault,
                    accessibilityIdentifier: "NewPasswordField",
                    passwordVisibilityAccessibilityId: "NewPasswordVisibilityToggle",
                    isPasswordVisible: store.binding(
                        get: \.isMasterPasswordRevealed,
                        send: SetMasterPasswordAction.revealMasterPasswordFieldPressed,
                    ),
                )
                .textFieldConfiguration(.password)

                BitwardenTextField(
                    title: Localizations.retypeMasterPasswordRequired,
                    text: store.binding(
                        get: \.masterPasswordRetype,
                        send: SetMasterPasswordAction.masterPasswordRetypeChanged,
                    ),
                    accessibilityIdentifier: "RetypePasswordField",
                    passwordVisibilityAccessibilityId: "RetypePasswordVisibilityToggle",
                    isPasswordVisible: store.binding(
                        get: \.isMasterPasswordRevealed,
                        send: SetMasterPasswordAction.revealMasterPasswordFieldPressed,
                    ),
                )
                .textFieldConfiguration(.password)

                BitwardenTextField(
                    title: Localizations.masterPasswordHint,
                    text: store.binding(
                        get: \.masterPasswordHint,
                        send: SetMasterPasswordAction.masterPasswordHintChanged,
                    ),
                    accessibilityIdentifier: "MasterPasswordHintLabel",
                    footerContent: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Localizations.bitwardenCannotResetALostOrForgottenMasterPassword)
                                .foregroundColor(Color(asset: SharedAsset.Colors.textSecondary))
                                .styleGuide(.footnote)

                            Button {
                                store.send(.preventAccountLockTapped)
                            } label: {
                                Text(Localizations.learnAboutWaysToPreventAccountLockout)
                            }
                            .buttonStyle(.bitwardenBorderless)
                        }
                        .padding(.vertical, 12)
                    },
                )
            }
        }
        .nativeFormRows()
        .passYNativeFormBackground()
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
