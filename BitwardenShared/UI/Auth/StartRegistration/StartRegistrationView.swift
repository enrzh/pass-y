import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - StartRegistrationView

/// A view that allows the user to create an account.
///
struct StartRegistrationView: View {
    // MARK: Properties

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The store used to render the view.
    @ObservedObject var store: Store<StartRegistrationState, StartRegistrationAction, StartRegistrationEffect>

    // MARK: View

    var body: some View {
        mainContent
            .navigationBar(
                title: Localizations.createAccount,
                titleDisplayMode: .inline,
            )
            .task {
                await store.perform(.appeared)
            }
            .toolbar {
                cancelToolbarItem {
                    store.send(.dismiss)
                }
            }
            .toast(
                store.binding(
                    get: \.toast,
                    send: StartRegistrationAction.toastShown,
                ),
            )
    }

    // MARK: Private views

    /// The main content: native grouped form with header, fields and prominent continue button.
    private var mainContent: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(Localizations.createAccount)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                regionRow

                TextField(Localizations.emailAddress, text: store.binding(
                    get: \.emailText,
                    send: StartRegistrationAction.emailTextChanged,
                ))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .accessibilityIdentifier("EmailAddressEntry")
                .id(Localizations.emailAddress)

                TextField(Localizations.name, text: store.binding(
                    get: \.nameText,
                    send: StartRegistrationAction.nameTextChanged,
                ))
                .textContentType(.name)
                .accessibilityIdentifier("NameEntry")
                .id(Localizations.name)

                receiveMarketingToggle
            } footer: {
                Text(LocalizedStringKey(store.state.termsAndPrivacyDisclaimerText))
                    .font(.footnote)
                    .accessibilityLinks(in: store.state.termsAndPrivacyDisclaimerText)
            }

            Section {
                continueButton
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .passYNativeFormBackground()
    }

    /// The server row.
    private var regionRow: some View {
        Button {
            Task { await store.perform(.regionTapped) }
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
    }

    /// The button pressed when the user attempts to create the account.
    private var continueButton: some View {
        Button {
            Task {
                await store.perform(.startRegistration)
            }
        } label: {
            Text(Localizations.continue)
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("ContinueButton")
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 16)
    }

    /// A toggle for the marketing emails.
    @ViewBuilder private var receiveMarketingToggle: some View {
        if store.state.showReceiveMarketingToggle {
            Toggle(isOn: store.binding(
                get: \.isReceiveMarketingToggleOn,
                send: StartRegistrationAction.toggleReceiveMarketing,
            )) {
                Text(LocalizedStringKey(store.state.receiveMarketingEmailsText))
                    .font(.subheadline)
            }
            .accessibilityIdentifier("ReceiveMarketingToggle")
            .accessibilityLinks(in: store.state.receiveMarketingEmailsText, isDefaultActionEnabled: false)
            .id(ViewIdentifier.StartRegistration.receiveMarketing)
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    StartRegistrationView(store: Store(processor: StateProcessor(state: StartRegistrationState())))
}

#Preview("Native Create Account Flow") {
    StartRegistrationView(
        store: Store(
            processor: StateProcessor(
                state: StartRegistrationState(),
            ),
        ),
    )
}
#endif
