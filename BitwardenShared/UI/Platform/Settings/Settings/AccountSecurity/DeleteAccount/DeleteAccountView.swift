import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - DeleteAccountView

/// A view that lets the user delete their account.
///
struct DeleteAccountView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<DeleteAccountState, DeleteAccountAction, DeleteAccountEffect>

    // MARK: View

    var body: some View {
        Form {
            viewContent
        }
        .navigationBar(title: Localizations.deleteAccount, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.loadData)
        }
    }

    /// The content is presented to the user depending on their state.
    @ViewBuilder var viewContent: some View {
        HStack(spacing: 12) {
            Image(decorative: store.state.mainIcon)
                .foregroundColor(Color(asset: SharedAsset.Colors.error))

            VStack(alignment: .leading, spacing: 2) {
                Text(store.state.title)
                    .foregroundColor(Color(asset: SharedAsset.Colors.error))
                    .styleGuide(
                        .headline,
                        weight: .semibold,
                        includeLinePadding: false,
                        includeLineSpacing: false,
                    )

                Text(store.state.description)
                    .foregroundColor(Color(asset: SharedAsset.Colors.textSecondary))
                    .styleGuide(.subheadline)
            }
        }

        if store.state.showDeleteAccountButtons {
            Section {
                AsyncButton(role: .destructive) {
                    await store.perform(.deleteAccount)
                } label: {
                    Text(Localizations.deleteAccount)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("DELETE ACCOUNT")

                Button {
                    store.send(.dismiss)
                } label: {
                    Text(Localizations.cancel)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("CancelDeletionButton")
            }
        }
    }
}

// MARK: Previews

#Preview {
    DeleteAccountView(store: Store(processor: StateProcessor(state: DeleteAccountState())))
}
