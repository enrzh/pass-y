import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LoginView

/// A view that allows the user to input their master password to complete the
/// login flow, or allows the user to navigate to separate views for alternate
/// forms of login.
///
struct LoginView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<LoginState, LoginAction, LoginEffect>

    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    Group {
                        if store.state.isMasterPasswordRevealed {
                            TextField(Localizations.masterPassword, text: passwordBinding)
                        } else {
                            SecureField(Localizations.masterPassword, text: passwordBinding)
                        }
                    }
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.go)
                    .focused($isPasswordFocused)
                    .accessibilityIdentifier("LoginMasterPasswordEntry")
                    .onSubmit {
                        Task { await store.perform(.loginWithMasterPasswordPressed) }
                    }

                    Button {
                        store.send(.revealMasterPasswordFieldPressed(!store.state.isMasterPasswordRevealed))
                    } label: {
                        Image(systemName: store.state.isMasterPasswordRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("PasswordVisibilityToggle")
                    .accessibilityLabel(
                        store.state.isMasterPasswordRevealed
                            ? Localizations.passwordIsVisibleTapToHide
                            : Localizations.passwordIsNotVisibleTapToShow,
                    )
                }

                Button(Localizations.getMasterPasswordwordHint) {
                    store.send(.getMasterPasswordHintPressed)
                }
                .accessibilityIdentifier("GetMasterPasswordHintLabel")
            }

            Section {
                loginButtons
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Section {
                loggedInAs
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle(Localizations.bitwarden)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            optionsToolbarMenu {
                Button(Localizations.getMasterPasswordwordHint) {
                    store.send(.getMasterPasswordHintPressed)
                }
            }
        }
        .task {
            await store.perform(.appeared)
            isPasswordFocused = true
        }
    }

    private var passwordBinding: Binding<String> {
        store.binding(get: \.masterPassword, send: LoginAction.masterPasswordChanged)
    }

    /// The set of login option buttons.
    @ViewBuilder var loginButtons: some View {
        VStack(alignment: .center, spacing: 12) {
            AsyncButton(Localizations.logInWithMasterPassword) {
                await store.perform(.loginWithMasterPasswordPressed)
            }
            .accessibilityIdentifier("LogInWithMasterPasswordButton")
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            if store.state.isLoginWithDeviceVisible {
                Button {
                    store.send(.loginWithDevicePressed)
                } label: {
                    Label(Localizations.logInWithDevice, systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("LogInWithAnotherDeviceButton")
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button {
                store.send(.enterpriseSingleSignOnPressed)
            } label: {
                Label(Localizations.logInSso, systemImage: "building.2")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("LogInWithSsoButton")
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
    }

    /// The "logged in as..." text along with the not you button.
    @ViewBuilder var loggedInAs: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(Localizations.loggedInAsOn(
                store.state.username,
                store.state.serverURLString,
            ))
            .accessibilityIdentifier("LoggingInAsLabel")
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button(Localizations.notYou) {
                store.send(.notYouPressed)
            }
            .accessibilityIdentifier("NotYouLabel")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty") {
    NavigationView {
        LoginView(
            store: Store(
                processor: StateProcessor(
                    state: LoginState(),
                ),
            ),
        )
    }
}

#Preview("With Device") {
    NavigationView {
        LoginView(
            store: Store(
                processor: StateProcessor(
                    state: LoginState(
                        isLoginWithDeviceVisible: true,
                    ),
                ),
            ),
        )
    }
}
#endif
