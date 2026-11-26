import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - RemoveMasterPasswordView

/// A view that notifies the user that they need to remove their master password.
///
struct RemoveMasterPasswordView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<RemoveMasterPasswordState, RemoveMasterPasswordAction, RemoveMasterPasswordEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("key.horizontal.fill", .accentColor),
                    title: Localizations.removeMasterPassword,
                    message: Localizations.removeMasterPasswordConfirmDomain,
                )
            }
            .passYPlainListRow()

            Section {
                PassYValueRow(Localizations.keyConnectorOrganization, value: store.state.organizationName)
                PassYValueRow(Localizations.keyConnectorDomain, value: store.state.keyConnectorUrl, isSelectable: true)
            }

            Section {
                PassYPasswordField(
                    Localizations.masterPassword,
                    text: store.binding(
                        get: \.masterPassword,
                        send: RemoveMasterPasswordAction.masterPasswordChanged,
                    ),
                    isRevealed: store.state.isMasterPasswordRevealed,
                    fieldIdentifier: "MasterPasswordEntry",
                ) { store.send(.revealMasterPasswordFieldPressed($0)) }
                    .focused($isPasswordFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await store.perform(.continueFlow)
                        }
                    }
            }

            PassYActionStack {
                Button {
                    Task { await store.perform(.continueFlow) }
                } label: {
                    Text(Localizations.continue).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)

                Button(role: .destructive) {
                    Task { await store.perform(.leaveOrganizationFlow) }
                } label: {
                    Text(Localizations.leaveOrganization)
                }
                .buttonStyle(.borderless)
            }
        }
        .passYGroupedBackground()
        .navigationBar(title: Localizations.removeMasterPassword, titleDisplayMode: .inline)
        .task {
            isPasswordFocused = true
        }
    }

    /// Whether the master password field has focus (focused when the page appears).
    @FocusState private var isPasswordFocused: Bool
}

// MARK: - Previews

#if DEBUG
#Preview("RemoveMasterPassword") {
    RemoveMasterPasswordView(
        store: Store(
            processor: StateProcessor(
                state: RemoveMasterPasswordState(
                    masterPassword: "password",
                    organizationName: "Example Org",
                    organizationId: "Mock-Id",
                    keyConnectorUrl: "www.example.com",
                ),
            ),
        ),
    )
    .navStackWrapped
}
#endif
