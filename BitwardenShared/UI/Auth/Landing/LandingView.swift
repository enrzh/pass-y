import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LandingView

/// A view that allows the user to input their email address to begin the login flow,
/// or allows the user to navigate to the account creation flow.
///
struct LandingView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<LandingState, LandingAction, LandingEffect>

    var body: some View {
        ZStack {
            mainContent
            profileSwitcher
        }
        .navigationBarTitle(Localizations.bitwarden, displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !store.state.profileSwitcherState.accounts.isEmpty {
                    profileSwitcherToolbarItem
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .task {
            await store.perform(.appeared)
        }
        .toast(store.binding(
            get: \.toast,
            send: LandingAction.toastShown,
        ))
    }

    // MARK: Private Views

    /// The Toolbar item for the profile switcher view
    private var profileSwitcherToolbarItem: some View {
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

    /// A view that displays the ability to add or switch between account profiles
    private var profileSwitcher: some View {
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

    /// The main content of the view: a native grouped form (server, email, remember me) with prominent actions below.
    private var mainContent: some View {
        Form {
            Section {
                PassYHeroHeader(title: Localizations.logInToBitwarden)
            }
            .passYPlainListRow()

            Section {
                PassYSettingsRow(
                    Localizations.server,
                    systemImage: "server.rack",
                    tint: .gray,
                    value: store.state.serverHost ?? Localizations.serverNotSet,
                    identifier: "RegionSelectorDropdown",
                ) {
                    Task { await store.perform(.regionPressed) }
                }

                TextField(
                    Localizations.emailAddress,
                    text: store.binding(get: \.email, send: LandingAction.emailChanged),
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.continue)
                .accessibilityIdentifier("LoginEmailAddressEntry")
                .onSubmit {
                    guard store.state.isContinueButtonEnabled else { return }
                    Task { await store.perform(.continuePressed) }
                }

                PassYToggleRow(
                    Localizations.rememberMe,
                    isOn: store.binding(
                        get: { $0.isRememberMeOn },
                        send: { .rememberMeChanged($0) },
                    ),
                    identifier: "RememberMeSwitch",
                )
            }

            Section {
                VStack(spacing: PassYDesign.Spacing.medium) {
                    Button {
                        Task { await store.perform(.continuePressed) }
                    } label: {
                        Text(Localizations.continue)
                            .frame(maxWidth: .infinity)
                    }
                    .passYButtonStyle(.primary, fillsWidth: true)
                    .accessibilityIdentifier("ContinueButton")
                    .disabled(!store.state.isContinueButtonEnabled)

                    if !store.state.isCreateAccountButtonHidden {
                        Button(Localizations.createAccount) {
                            store.send(.createAccountPressed)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("CreateAccountButton")
                    }

                    Button {
                        store.send(.showPreLoginSettings)
                    } label: {
                        Label(Localizations.appSettings, systemImage: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("AppSettingsButton")
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
            }
            .passYPlainListRow()
        }
        // Without an explicit container, a disabled Continue button prevents Full Keyboard Access
        // from navigating to the buttons below it.
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty Email") {
    NavigationView {
        LandingView(
            store: Store(
                processor: StateProcessor(
                    state: LandingState(
                        email: "",
                        isRememberMeOn: false,
                    ),
                ),
            ),
        )
    }
}

#Preview("Example Email") {
    NavigationView {
        LandingView(
            store: Store(
                processor: StateProcessor(
                    state: LandingState(
                        email: "email@example.com",
                        isRememberMeOn: true,
                    ),
                ),
            ),
        )
    }
}

#Preview("Profiles Closed") {
    NavigationView {
        LandingView(
            store: Store(
                processor: StateProcessor(
                    state: LandingState(
                        email: "",
                        isRememberMeOn: false,
                        profileSwitcherState: ProfileSwitcherState.singleAccountHidden,
                    ),
                ),
            ),
        )
    }
}

#Preview("Profiles Open") {
    NavigationView {
        LandingView(
            store: Store(
                processor: StateProcessor(
                    state: LandingState(
                        email: "",
                        isRememberMeOn: false,
                        profileSwitcherState: ProfileSwitcherState.singleAccount,
                    ),
                ),
            ),
        )
    }
}
#endif
