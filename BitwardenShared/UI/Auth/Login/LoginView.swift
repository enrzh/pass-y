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
                PassYHeroHeader(title: Localizations.logIn)
            }
            .passYPlainListRow()

            Section {
                PassYSecureField(
                    Localizations.masterPassword,
                    text: passwordBinding,
                    isRevealed: store.state.isMasterPasswordRevealed,
                    fieldIdentifier: "LoginMasterPasswordEntry",
                ) { store.send(.revealMasterPasswordFieldPressed($0)) }
                    .submitLabel(.go)
                    .focused($isPasswordFocused)
                    .onSubmit {
                        Task { await store.perform(.loginWithMasterPasswordPressed) }
                    }
            } footer: {
                Button(Localizations.getMasterPasswordwordHint) {
                    store.send(.getMasterPasswordHintPressed)
                }
                .font(.footnote)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("GetMasterPasswordHintLabel")
            }

            Section {
                loginButtons
            }
            .passYPlainListRow()

            Section {
                loggedInAs
            }
            .passYPlainListRow()
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

    /// The login actions: one primary action, the other ways to log in as secondary buttons.
    @ViewBuilder var loginButtons: some View {
        VStack(alignment: .center, spacing: PassYDesign.Spacing.medium) {
            Button {
                Task { await store.perform(.loginWithMasterPasswordPressed) }
            } label: {
                Text(Localizations.logInWithMasterPassword)
                    .frame(maxWidth: .infinity)
            }
            .passYButtonStyle(.primary, fillsWidth: true)
            .accessibilityIdentifier("LogInWithMasterPasswordButton")

            if store.state.isLoginWithDeviceVisible {
                Button {
                    store.send(.loginWithDevicePressed)
                } label: {
                    Label(Localizations.logInWithDevice, systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.secondary, fillsWidth: true)
                .accessibilityIdentifier("LogInWithAnotherDeviceButton")
            }

            Button {
                store.send(.enterpriseSingleSignOnPressed)
            } label: {
                Label(Localizations.logInSso, systemImage: "building.2")
                    .frame(maxWidth: .infinity)
            }
            .passYButtonStyle(.secondary, fillsWidth: true)
            .accessibilityIdentifier("LogInWithSsoButton")
        }
        .padding(.horizontal, PassYDesign.Spacing.large)
    }

    /// The account the login is for, with a "Not you?" button back to the landing screen.
    @ViewBuilder var loggedInAs: some View {
        VStack(alignment: .center, spacing: PassYDesign.Spacing.xSmall) {
            Text(Localizations.loggedInAsOn(store.state.username, store.state.serverURLString))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("LoggingInAsLabel")

            Button(Localizations.notYou) {
                store.send(.notYouPressed)
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.borderless)
            .accessibilityIdentifier("NotYouLabel")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, PassYDesign.Spacing.small)
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
