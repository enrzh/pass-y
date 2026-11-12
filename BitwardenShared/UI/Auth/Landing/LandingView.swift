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
                VStack(spacing: 12) {
                    Image(decorative: Asset.Images.logo)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.tint)
                        .frame(maxWidth: 220, maxHeight: 34)
                    Text(Localizations.logInToBitwarden)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)
            }

            Section {
                Button {
                    Task { await store.perform(.regionPressed) }
                } label: {
                    HStack {
                        Label(Localizations.server, systemImage: "server.rack")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(store.state.serverHost ?? Localizations.serverNotSet)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("RegionSelectorDropdown")
                .accessibilityLabel("\(Localizations.server): \(store.state.serverHost ?? Localizations.serverNotSet)")

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

                Toggle(Localizations.rememberMe, isOn: store.binding(
                    get: { $0.isRememberMeOn },
                    send: { .rememberMeChanged($0) },
                ))
                .accessibilityIdentifier("RememberMeSwitch")
            }

            Section {
                AsyncButton {
                    await store.perform(.continuePressed)
                } label: {
                    Text(Localizations.continue)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("ContinueButton")
                .disabled(!store.state.isContinueButtonEnabled)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if !store.state.isCreateAccountButtonHidden {
                    Button(Localizations.createAccount) {
                        store.send(.createAccountPressed)
                    }
                    .accessibilityIdentifier("CreateAccountButton")
                }

                Button {
                    store.send(.showPreLoginSettings)
                } label: {
                    Label(Localizations.appSettings, systemImage: "gearshape")
                }
                .accessibilityIdentifier("AppSettingsButton")
            }
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
