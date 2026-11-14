import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CompleteRegistrationView

/// A view that allows the user to create an account.
///
struct CompleteRegistrationView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<
        CompleteRegistrationState,
        CompleteRegistrationAction,
        CompleteRegistrationEffect,
    >

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(Localizations.chooseYourMasterPassword)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(Localizations.chooseAUniqueAndStrongPasswordToKeepYourInformationSafe)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(Localizations.learnMore) {
                        store.send(.learnMoreTapped)
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                passwordField
                retypePassword
                PasswordStrengthIndicator(
                    passwordStrengthScore: store.state.passwordStrengthScore,
                    passwordTextCount: store.state.passwordText.count,
                    requiredTextCount: store.state.requiredPasswordCount,
                )
            }

            Section {
                passwordHint
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Localizations.bitwardenCannotResetALostOrForgottenMasterPassword)
                    Button(Localizations.learnAboutWaysToPreventAccountLockout) {
                        store.send(.preventAccountLockTapped)
                    }
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                }
            }

            Section {
                checkBreachesToggle
            }

            Section {
                createAccountButton
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .passYNativeFormBackground()
        .animation(.default, value: store.state.passwordStrengthScore)
        .navigationBar(
            title: Localizations.createAccount,
            titleDisplayMode: .inline,
        )
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.appeared)
        }
        .toast(store.binding(
            get: \.toast,
            send: CompleteRegistrationAction.toastShown,
        ))
    }

    // MARK: Private views

    /// A toggle to check the user's password for security breaches.
    private var checkBreachesToggle: some View {
        Toggle(isOn: store.binding(
            get: \.isCheckDataBreachesToggleOn,
            send: CompleteRegistrationAction.toggleCheckDataBreaches,
        )) {
            Text(Localizations.checkKnownDataBreachesForThisPassword)
                .font(.subheadline)
        }
        .accessibilityIdentifier("CheckExposedMasterPasswordToggle")
        .id(ViewIdentifier.CompleteRegistration.checkBreaches)
    }

    /// A password field with a reveal button.
    private func secureRow(
        title: String,
        text: Binding<String>,
        visible: Binding<Bool>,
        fieldId: String,
        toggleId: String,
    ) -> some View {
        HStack {
            if visible.wrappedValue {
                TextField(title, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .accessibilityIdentifier(fieldId)
                    .id(title)
            } else {
                SecureField(title, text: text)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .accessibilityIdentifier(fieldId)
                    .id(title)
            }

            Button {
                visible.wrappedValue.toggle()
            } label: {
                Image(systemName: visible.wrappedValue ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(toggleId)
            .accessibilityLabel(
                visible.wrappedValue
                    ? Localizations.passwordIsVisibleTapToHide
                    : Localizations.passwordIsNotVisibleTapToShow,
            )
        }
    }

    /// The master password field.
    private var passwordField: some View {
        secureRow(
            title: Localizations.masterPasswordRequired,
            text: store.binding(
                get: \.passwordText,
                send: CompleteRegistrationAction.passwordTextChanged,
            ),
            visible: store.binding(
                get: \.arePasswordsVisible,
                send: CompleteRegistrationAction.togglePasswordVisibility,
            ),
            fieldId: "MasterPasswordEntry",
            toggleId: "PasswordVisibilityToggle",
        )
    }

    /// The master password hint.
    private var passwordHint: some View {
        TextField(Localizations.masterPasswordHint, text: store.binding(
            get: \.passwordHintText,
            send: CompleteRegistrationAction.passwordHintTextChanged,
        ))
        .accessibilityIdentifier("MasterPasswordHintLabel")
        .id(Localizations.masterPasswordHint)
    }

    /// The text field for re-typing the master password.
    private var retypePassword: some View {
        secureRow(
            title: Localizations.retypeMasterPasswordRequired,
            text: store.binding(
                get: \.retypePasswordText,
                send: CompleteRegistrationAction.retypePasswordTextChanged,
            ),
            visible: store.binding(
                get: \.arePasswordsVisible,
                send: CompleteRegistrationAction.togglePasswordVisibility,
            ),
            fieldId: "ConfirmMasterPasswordEntry",
            toggleId: "ConfirmPasswordVisibilityToggle",
        )
    }

    /// The button pressed when the user attempts to create the account.
    private var createAccountButton: some View {
        Button {
            Task {
                await store.perform(.completeRegistration)
            }
        } label: {
            Text(Localizations.continue)
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("CreateAccountButton")
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .disabled(!store.state.continueButtonEnabled)
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    CompleteRegistrationView(store: Store(processor: StateProcessor(
        state: CompleteRegistrationState(
            emailVerificationToken: "emailVerificationToken",
            userEmail: "example@bitwarden.com",
        ),
    )))
}
#endif
