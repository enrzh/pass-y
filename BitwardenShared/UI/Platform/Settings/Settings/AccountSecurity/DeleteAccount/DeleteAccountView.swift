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

    /// The warning (or why the account cannot be deleted), then the destructive action and a plain cancel button.
    @ViewBuilder var viewContent: some View {
        Section {
            PassYHeroHeader(
                mark: .symbol(
                    store.state.shouldPreventUserFromDeletingAccount ? "xmark.octagon.fill" : "exclamationmark.triangle.fill",
                    .red,
                ),
                title: store.state.title,
                message: store.state.description,
            )
        }
        .passYPlainListRow()

        if store.state.showDeleteAccountButtons {
            Section {
                VStack(spacing: PassYDesign.Spacing.medium) {
                    Button(role: .destructive) {
                        Task { await store.perform(.deleteAccount) }
                    } label: {
                        Text(Localizations.deleteAccount)
                            .frame(maxWidth: .infinity)
                    }
                    .passYButtonStyle(.destructive, fillsWidth: true)
                    .accessibilityIdentifier("DELETE ACCOUNT")

                    Button(Localizations.cancel) {
                        store.send(.dismiss)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("CancelDeletionButton")
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
            }
            .passYPlainListRow()
        }
    }
}

// MARK: Previews

#Preview {
    DeleteAccountView(store: Store(processor: StateProcessor(state: DeleteAccountState())))
}
