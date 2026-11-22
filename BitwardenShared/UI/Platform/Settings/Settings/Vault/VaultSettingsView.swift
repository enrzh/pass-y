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
    }

    // MARK: Private views

    /// The action card for setting up vault unlock methods.
    @ViewBuilder private var importLoginsActionCard: some View {
        if store.state.shouldShowImportLoginsActionCard {
            NativeSetupSection(
                title: Localizations.importSavedLogins,
                message: Localizations.importSavedLoginsDescriptionLong,
                systemImage: "square.and.arrow.down",
                action: NativeSetupSection.Row(title: Localizations.getStarted) {
                    store.send(.showImportLogins)
                },
                dismiss: NativeSetupSection.Row(title: Localizations.dismiss) {
                    await store.perform(.dismissImportLoginsActionCard)
                },
            )
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
        }
    }
}

#Preview {
    VaultSettingsView(store: Store(processor: StateProcessor(state: VaultSettingsState())))
}
