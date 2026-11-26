import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - CheckEmailView

/// A view that allows the user to create an account.
///
struct CheckEmailView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The store used to render the view.
    @ObservedObject var store: Store<CheckEmailState, CheckEmailAction, Void>

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(spacing: PassYDesign.Spacing.small) {
                    PassYHeroHeader(
                        mark: .symbol("envelope.badge.fill", .accentColor),
                        title: Localizations.checkYourEmail,
                    )
                    Text(LocalizedStringKey(store.state.headelineTextBoldEmail))
                        .font(.headline)
                        .tint(.primary)
                    Text(Localizations.selectTheLinkInTheEmailToVerifyYourEmailAddressAndContinueCreatingYourAccount)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .passYPlainListRow()

            PassYActionStack {
                Button {
                    openURL(URL(string: "message://")!)
                } label: {
                    Text(Localizations.openEmailApp).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
                .accessibilityIdentifier("OpenEmailAppButton")

                Button(Localizations.changeEmailAddress) {
                    store.send(.goBackTapped)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("ChangeEmailAddressButton")
            }
        }
        .navigationBar(title: Localizations.createAccount, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismissTapped)
            }
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    CheckEmailView(store: Store(processor: StateProcessor(state: CheckEmailState(email: "email@example.com"))))
}
#endif
