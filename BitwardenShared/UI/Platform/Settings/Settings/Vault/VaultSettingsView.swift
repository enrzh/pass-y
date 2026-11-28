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
            importLoginsActionCard

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
        .onAppear {
            Task { await store.perform(.loadEncryptedBackupStatus) }
        }
    }

    // MARK: Private views

    /// The action card for setting up vault unlock methods.
    @ViewBuilder private var importLoginsActionCard: some View {
        if store.state.shouldShowImportLoginsActionCard {
            PassYSetupSection(
                title: Localizations.importSavedLogins,
                message: Localizations.importSavedLoginsDescriptionLong,
                systemImage: "square.and.arrow.down.fill",
                tint: .blue,
                action: .init(title: Localizations.getStarted) {
                    store.send(.showImportLogins)
                },
                dismiss: .init(title: Localizations.dismiss) {
                    await store.perform(.dismissImportLoginsActionCard)
                },
            )
        }
    }

    /// The vault settings section.
    private var vaultSettings: some View {
        Section {
            PassYSettingsRow(Localizations.myFolders, systemImage: "folder.fill", tint: .blue, identifier: "FoldersLabel") {
                store.send(.foldersTapped)
            }

            PassYSettingsRow(
                Localizations.exportVault,
                systemImage: "square.and.arrow.up.fill",
                tint: .orange,
                identifier: "ExportVaultLabel",
            ) {
                store.send(.exportVaultTapped)
            }

            PassYSettingsRow(
                Localizations.encryptedBackup,
                systemImage: "lock.doc.fill",
                tint: .indigo,
                value: store.state.encryptedBackupValue,
                badge: store.state.encryptedBackupBadge,
                identifier: "EncryptedBackupLabel",
            ) {
                store.send(.encryptedBackupTapped)
            }
        }
    }
}

#Preview {
    VaultSettingsView(store: Store(processor: StateProcessor(state: VaultSettingsState())))
}
