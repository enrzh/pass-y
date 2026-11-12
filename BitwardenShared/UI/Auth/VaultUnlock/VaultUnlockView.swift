import BitwardenKit
import BitwardenResources
import SwiftUI

/// A view that allows the user to enter their master password to unlock the vault or logout of the
/// current account.
///
struct VaultUnlockView: View {
    // MARK: Private Types

    /// The fields in the view that can be focused.
    private enum FocusedField: Hashable {
        /// The master password or PIN field.
        case passwordOrPin
    }

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultUnlockState, VaultUnlockAction, VaultUnlockEffect>

    /// The text to display in the footer of the password/pin text field.
    var footerText: String {
        """
        \(store.state.unlockMethod == .pin
            ? Localizations.vaultLockedPIN
            : Localizations.vaultLockedMasterPassword)

        \(Localizations.loggedInAsOn(store.state.email, store.state.webVaultHost))
        """
    }

    /// The view's navigation title.
    var navigationTitle: String {
        store.state.unlockMethod == .pin
            ? Localizations.verifyPIN
            : Localizations.verifyMasterPassword
    }

    // MARK: Private Properties

    /// The field that currently has focus.
    @FocusState private var focusedField: FocusedField?

    // MARK: View

    var body: some View {
        ZStack {
            scrollView
            profileSwitcher
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.state.isInAppExtension {
                    cancelToolbarButton {
                        store.send(.cancelPressed)
                    }
                } else {
                    optionsToolbarMenu {
                        Button(Localizations.logOut) {
                            store.send(.logOut)
                        }
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                profileSwitcherToolbarItem
            }
        }
        .task {
            await store.perform(.appeared)
        }
        .onChange(of: store.state.shouldFocusPasswordOrPinField) { shouldFocus in
            focusedField = shouldFocus ? .passwordOrPin : nil
        }
        .toast(store.binding(
            get: \.toast,
            send: VaultUnlockAction.toastShown,
        ))
    }

    /// The content of the view: a native grouped form with the credential field and the unlock actions.
    @ViewBuilder var scrollView: some View {
        Form {
            if store.state.shouldShowPasswordOrPinFields {
                Section {
                    textField
                } footer: {
                    Text(footerText)
                        .accessibilityIdentifier("UserAndEnvironmentDataLabel")
                }
            }

            Section {
                VStack(spacing: 12) {
                    biometricAuthButton
                    if store.state.shouldShowPasswordOrPinFields {
                        AsyncButton {
                            await store.perform(.unlockVault)
                        } label: {
                            Text(Localizations.unlock)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("UnlockVaultButton")
                    }
                }
                .padding(.horizontal, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    /// The Toolbar item for the profile switcher view.
    @ViewBuilder var profileSwitcherToolbarItem: some View {
        ProfileSwitcherToolbarView(
            store: store.child(
                state: { state in
                    state.profileSwitcherState
                },
                mapAction: { action in
                    .profileSwitcher(action)
                },
                mapEffect: { effect in
                    .profileSwitcher(effect)
                },
            ),
        )
    }

    /// A button to trigger a biometric auth unlock.
    @ViewBuilder private var biometricAuthButton: some View {
        if case let .available(biometryType, true) = store.state.biometricUnlockStatus {
            AsyncButton {
                Task { await store.perform(.unlockVaultWithBiometrics) }
            } label: {
                biometricUnlockText(biometryType)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    /// A view that displays the ability to add or switch between account profiles
    @ViewBuilder private var profileSwitcher: some View {
        ProfileSwitcherView(
            store: store.child(
                state: { mainState in
                    mainState.profileSwitcherState
                },
                mapAction: { action in
                    .profileSwitcher(action)
                },
                mapEffect: { profileEffect in
                    .profileSwitcher(profileEffect)
                },
            ),
        )
    }

    /// The field for the pin or password: a native secure field with a reveal toggle.
    @ViewBuilder private var textField: some View {
        switch store.state.unlockMethod {
        case .password:
            credentialField(
                title: Localizations.masterPassword,
                text: store.binding(get: \.masterPassword, send: VaultUnlockAction.masterPasswordChanged),
                isRevealed: store.state.isMasterPasswordRevealed,
                onReveal: { store.send(.revealMasterPasswordFieldPressed(!store.state.isMasterPasswordRevealed)) },
                fieldIdentifier: "MasterPasswordEntry",
                toggleIdentifier: "PasswordVisibilityToggle",
                keyboard: .default,
            )
        case .pin:
            credentialField(
                title: Localizations.pin,
                text: store.binding(get: \.pin, send: VaultUnlockAction.pinChanged),
                isRevealed: store.state.isPinRevealed,
                onReveal: { store.send(.revealPinFieldPressed(!store.state.isPinRevealed)) },
                fieldIdentifier: "PinEntry",
                toggleIdentifier: "PinVisibilityToggle",
                keyboard: .numberPad,
            )
        }
    }

    private func credentialField(
        title: String,
        text: Binding<String>,
        isRevealed: Bool,
        onReveal: @escaping () -> Void,
        fieldIdentifier: String,
        toggleIdentifier: String,
        keyboard: UIKeyboardType,
    ) -> some View {
        HStack {
            Group {
                if isRevealed {
                    TextField(title, text: text)
                } else {
                    SecureField(title, text: text)
                }
            }
            .keyboardType(keyboard)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.go)
            .focused($focusedField, equals: .passwordOrPin)
            .accessibilityIdentifier(fieldIdentifier)
            .onSubmit {
                Task { await store.perform(.unlockVault) }
            }

            Button(action: onReveal) {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(toggleIdentifier)
            .accessibilityLabel(
                isRevealed ? Localizations.passwordIsVisibleTapToHide : Localizations.passwordIsNotVisibleTapToShow,
            )
        }
    }

    private func biometricUnlockText(_ biometryType: BiometricAuthenticationType) -> some View {
        switch biometryType {
        case .faceID:
            Text(Localizations.useFaceIDToUnlock)
        case .opticID:
            Text(Localizations.useOpticIDToUnlock)
        case .touchID:
            Text(Localizations.useFingerprintToUnlock)
        case .unknown:
            Text(Localizations.useBiometricsToUnlock)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Vault Unlock") {
    NavigationView {
        VaultUnlockView(
            store: Store(
                processor: StateProcessor(
                    state: VaultUnlockState(
                        email: "user@bitwarden.com",
                        profileSwitcherState: .empty(),
                        unlockMethod: .password,
                        webVaultHost: "vault.bitwarden.com",
                    ),
                ),
            ),
        )
    }
}

#Preview("Profiles Closed") {
    NavigationView {
        VaultUnlockView(
            store: Store(
                processor: StateProcessor(
                    state: VaultUnlockState(
                        email: "user@bitwarden.com",
                        profileSwitcherState: .singleAccountHidden,
                        unlockMethod: .pin,
                        webVaultHost: "vault.bitwarden.com",
                    ),
                ),
            ),
        )
    }
}

#Preview("Profiles Open") {
    NavigationView {
        VaultUnlockView(
            store: Store(
                processor: StateProcessor(
                    state: VaultUnlockState(
                        email: "user@bitwarden.com",
                        profileSwitcherState: .singleAccount,
                        unlockMethod: .password,
                        webVaultHost: "vault.bitwarden.com",
                    ),
                ),
            ),
        )
    }
}
#endif
