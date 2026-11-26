import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SingleSignOnView

/// A view that allows users to login using their single-sign on identifier.
///
struct SingleSignOnView: View {
    // MARK: Properties

    @ObservedObject var store: Store<SingleSignOnState, SingleSignOnAction, SingleSignOnEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                identifierTextField
            } header: {
                instructionsText
                    .textCase(nil)
            }
        }
        .passYGroupedBackground()
        .navigationBar(title: Localizations.bitwarden, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }

            ToolbarItem(placement: .topBarTrailing) {
                primaryActionToolbarButton(Localizations.logIn) {
                    await store.perform(.loginTapped)
                }
                .accessibilityIdentifier("SSOLoginButton")
            }
        }
        .task {
            await store.perform(.loadSingleSignOnDetails)
        }
    }

    // MARK: Private Views

    /// The identifier text field.
    private var identifierTextField: some View {
        TextField(Localizations.orgIdentifier, text: store.binding(
            get: \.identifierText,
            send: SingleSignOnAction.identifierTextChanged,
        ))
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .accessibilityIdentifier("SSOOrgIdField")
    }

    /// The instructions text.
    private var instructionsText: some View {
        Text(Localizations.logInSsoSummary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
    }
}

// MARK: Previews

#Preview {
    SingleSignOnView(store: Store(processor: StateProcessor(
        state: SingleSignOnState(),
    ))).navStackWrapped
}
