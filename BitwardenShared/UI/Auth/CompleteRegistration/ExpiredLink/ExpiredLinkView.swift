import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ExpiredLinkView

/// A view that allows the user to create an account.
///
struct ExpiredLinkView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<ExpiredLinkState, ExpiredLinkAction, Void>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("clock.badge.exclamationmark.fill", .orange),
                    title: Localizations.expiredLink,
                    message: Localizations.pleaseRestartRegistrationOrTryLoggingInYouMayAlreadyHaveAnAccount,
                )
            }
            .passYPlainListRow()

            PassYActionStack {
                Button {
                    store.send(.restartRegistrationTapped)
                } label: {
                    Text(Localizations.restartRegistration).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
                .accessibilityIdentifier("RestartRegistrationButton")

                Button(Localizations.logIn) {
                    store.send(.logInTapped)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("LogInButton")
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
    ExpiredLinkView(store: Store(processor: StateProcessor(state: ExpiredLinkState())))
}
#endif
