import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - VaultSettingsView

/// A view that allows users to view their vault settings and folders.
///
struct VaultSettingsView: View {
    // MARK: Properties

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultSettingsState, VaultSettingsAction, VaultSettingsEffect>

    // MARK: View

    var body: some View {
        Form {
            if store.state.shouldShowImportLoginsActionCard {
                Section {
                    importLoginsActionCard
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            vaultSettings
        }
        .animation(.easeInOut, value: store.state.badgeState?.importLoginsSetupProgress == .complete)
        .navigationBar(title: Localizations.vault, titleDisplayMode: .inline)
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearUrl)
        }
        .task {
            await store.perform(.streamSettingsBadge)
        }
    }

    // MARK: Private views

    /// The action card for setting up vault unlock methods.
    @ViewBuilder private var importLoginsActionCard: some View {
        if store.state.shouldShowImportLoginsActionCard {
            ActionCard(
                title: Localizations.importSavedLogins,
                message: Localizations.importSavedLoginsDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.getStarted) {
                    store.send(.showImportLogins)
                },
                dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                    await store.perform(.dismissImportLoginsActionCard)
                },
            ) {
                BitwardenBadge(badgeValue: "1")
            }
        }
    }

    /// A native navigation row.
    private func row(
        _ title: String,
        systemImage: String,
        trailing: String = "chevron.right",
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: trailing)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The vault settings section.
    private var vaultSettings: some View {
        Section {
            row(Localizations.myFolders, systemImage: "folder") {
                store.send(.foldersTapped)
            }
            .accessibilityIdentifier("FoldersLabel")

            row(Localizations.exportVault, systemImage: "square.and.arrow.up") {
                store.send(.exportVaultTapped)
            }
            .accessibilityIdentifier("ExportVaultLabel")

            row(Localizations.importItems, systemImage: "square.and.arrow.down", trailing: "arrow.up.right") {
                store.send(.importItemsTapped)
            }
            .accessibilityIdentifier("ImportItemsLinkItemView")
        }
    }
}

#Preview {
    VaultSettingsView(store: Store(processor: StateProcessor(state: VaultSettingsState())))
}
