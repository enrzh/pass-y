import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SyncWithBrowserView

/// A view shown when the app needs the user to sync SSO authentication through
/// their default browser.
///
struct SyncWithBrowserView: View {
    // MARK: Properties

    /// An object used to open URLs from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<SyncWithBrowserState, SyncWithBrowserAction, SyncWithBrowserEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("safari.fill", .accentColor),
                    title: Localizations.syncWithBrowser,
                    message: Localizations.syncWithBrowserDescriptionLong(store.state.vaultUrl),
                )
            }
            .passYPlainListRow()

            PassYActionStack {
                Button {
                    Task { await store.perform(.launchBrowserTapped) }
                } label: {
                    Label(Localizations.launchBrowser, systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)

                Button(Localizations.continueWithoutSyncing) {
                    store.send(.continueWithoutSyncingTapped)
                }
                .buttonStyle(.borderless)
            }
        }
        .dismissKeyboardOnAppear()
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    SyncWithBrowserView(
        store: Store(
            processor: StateProcessor(
                state: SyncWithBrowserState(
                    vaultUrl: "https://example.bitwarden.com",
                ),
            ),
        ),
    )
    .navStackWrapped
}
#endif
