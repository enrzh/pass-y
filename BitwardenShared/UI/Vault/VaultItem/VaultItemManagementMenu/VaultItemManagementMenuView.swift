import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - VaultItemManagementMenuView

/// A menu view for displaying options for vault management.
struct VaultItemManagementMenuView: View {
    // MARK: Properties

    /// The flag for whether to show the archive option.
    let isArchiveEnabled: Bool

    /// The flag for showing/hiding clone option.
    let isCloneEnabled: Bool

    /// The flag for whether to show the collections options.
    let isCollectionsEnabled: Bool

    /// The flag for whether to show the delete option.
    let isDeleteEnabled: Bool

    /// The flag for whether to show the move to organization options.
    let isMoveToOrganizationEnabled: Bool

    /// The flag for whether to show the restore option.
    let isRestoreEnabled: Bool

    /// The flag for whether to show the unarchive option.
    let isUnarchiveEnabled: Bool

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, VaultItemManagementMenuAction, VaultItemManagementMenuEffect>

    var body: some View {
        // A native pull-down menu from the "..." toolbar button (SF Symbols, destructive Delete after a divider).
        Menu {
            if isRestoreEnabled {
                Button {
                    store.send(.restore)
                } label: {
                    Label(Localizations.restore, systemImage: "arrow.uturn.backward")
                }
                .accessibilityIdentifier("RestoreButton")
            }

            Button {
                store.send(.attachments)
            } label: {
                Label(Localizations.attachments, systemImage: "paperclip")
            }

            if isCloneEnabled {
                Button {
                    store.send(.clone)
                } label: {
                    Label(Localizations.clone, systemImage: "plus.square.on.square")
                }
            }

            if isCollectionsEnabled {
                Button {
                    store.send(.editCollections)
                } label: {
                    Label(Localizations.sharedFolders, systemImage: "folder.badge.person.crop")
                }
            }

            if isMoveToOrganizationEnabled {
                Button {
                    store.send(.moveToOrganization)
                } label: {
                    Label(Localizations.move, systemImage: "folder")
                }
            }

            if isArchiveEnabled {
                AsyncButton {
                    await store.perform(.archiveItem)
                } label: {
                    Label(Localizations.archive, systemImage: "archivebox")
                }
            } else if isUnarchiveEnabled {
                AsyncButton {
                    await store.perform(.unarchiveItem)
                } label: {
                    Label(Localizations.unarchive, systemImage: "tray.and.arrow.up")
                }
            }

            if isDeleteEnabled {
                Divider()
                AsyncButton(role: .destructive) {
                    await store.perform(.deleteItem)
                } label: {
                    Label(Localizations.delete, systemImage: "trash")
                }
            }
        } label: {
            // The plain system symbol: the toolbar draws it like its other buttons.
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel(Localizations.options)
        .frame(minHeight: 44)
    }
}

#Preview {
    VaultItemManagementMenuView(
        isArchiveEnabled: true,
        isCloneEnabled: true,
        isCollectionsEnabled: true,
        isDeleteEnabled: true,
        isMoveToOrganizationEnabled: true,
        isRestoreEnabled: true,
        isUnarchiveEnabled: false,
        store: Store(
            processor: StateProcessor(
                state: (),
            ),
        ),
    )
}
