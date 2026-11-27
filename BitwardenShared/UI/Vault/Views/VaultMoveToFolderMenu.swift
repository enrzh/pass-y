import BitwardenResources
import BitwardenSdk
import Observation
import SwiftUI

// MARK: - VaultFolderMove

/// The folders and the move handlers of a vault list page, shared by all its rows through the environment
/// (`vaultFolderMove`). Only the "Move to folder" menus read `folders`, so a change of the folders never builds the rows
/// again (the rows themselves stay `VaultListRowCell`s compared by their state). Pages without it (extension lists)
/// offer no move.
@MainActor
@Observable
final class VaultFolderMove {
    /// The user's folders.
    var folders = [FolderView]()

    /// Moves the (cipher) item into the folder, `nil` for no folder.
    @ObservationIgnored var move: ((VaultListItem, String?) -> Void)?

    /// Asks for a folder name, creates the folder and moves the (cipher) item into it.
    @ObservationIgnored var moveToNewFolder: ((VaultListItem) -> Void)?
}

extension EnvironmentValues {
    /// The folder move of the vault list page, `nil` where items cannot be moved (extension lists).
    @Entry var vaultFolderMove: VaultFolderMove?
}

extension View {
    /// Gives the page's rows the "Move to folder" menu: the folders follow `folders`, a choice calls `move`, "New
    /// folder…" calls `moveToNewFolder`.
    ///
    /// - Parameters:
    ///   - model: The page's `VaultFolderMove` (a `@State` of the page).
    ///   - folders: The user's folders.
    ///   - move: Moves the item into a folder (`nil`: no folder).
    ///   - moveToNewFolder: Creates a folder and moves the item into it.
    ///
    func vaultFolderMove(
        _ model: VaultFolderMove,
        folders: [FolderView],
        move: @escaping (VaultListItem, String?) -> Void,
        moveToNewFolder: @escaping (VaultListItem) -> Void,
    ) -> some View {
        environment(\.vaultFolderMove, model)
            .onChange(of: folders, initial: true) { _, folders in
                model.folders = folders
            }
            .onAppear {
                model.move = move
                model.moveToNewFolder = moveToNewFolder
            }
    }
}

// MARK: - VaultMoveToFolderMenu

/// "Move to folder" as a native submenu of an item's menus (long press, the More swipe action): "No folder" and every
/// folder with a checkmark on the current one, then "New folder…". Shown only for items the user may move (see
/// `VaultListItem.folderMoveCipher`) on pages with a `vaultFolderMove`.
struct VaultMoveToFolderMenu: View {
    /// The item (a cipher row; a code row passes its cipher item).
    let item: VaultListItem?

    @Environment(\.vaultFolderMove) private var model

    var body: some View {
        if let model, let item, let cipher = item.folderMoveCipher, let move = model.move {
            VaultFolderPickerMenu(
                folders: model.folders,
                currentFolderId: cipher.folderId,
                select: { move(item, $0) },
                newFolder: model.moveToNewFolder.map { newFolder in { newFolder(item) } },
            )
        }
    }
}

// MARK: - VaultFolderPickerMenu

/// The "Move to folder" submenu itself (also used by the item view's "…" menu): an inline picker of "No folder" and the
/// folders (checkmark on the current one), then "New folder…".
struct VaultFolderPickerMenu: View {
    /// The folders offered.
    let folders: [FolderView]

    /// The item's folder, `nil` for none.
    let currentFolderId: String?

    /// Called with the chosen folder (`nil`: no folder); not called for the current one.
    let select: (String?) -> Void

    /// Starts "New folder…", `nil` for no such entry.
    var newFolder: (() -> Void)?

    var body: some View {
        Menu {
            Picker(
                Localizations.moveToFolder,
                selection: Binding<String?>(
                    get: { currentFolderId },
                    set: { folderId in
                        guard folderId != currentFolderId else { return }
                        select(folderId)
                    },
                ),
            ) {
                Text(Localizations.folderNone)
                    .tag(String?.none)
                ForEach(folders.filter { $0.id != nil }, id: \.id) { folder in
                    Text(folder.name)
                        .tag(folder.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            if let newFolder {
                Divider()
                Button(action: newFolder) {
                    Label(Localizations.newFolderEllipsis, systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier("MoveToNewFolderButton")
            }
        } label: {
            Label(Localizations.moveToFolder, systemImage: "folder")
        }
        .accessibilityIdentifier("MoveToFolderMenu")
    }
}

// MARK: - VaultListItem + folder move

extension VaultListItem {
    /// The cipher of a row that can be moved into a folder: a cipher the user may edit, not deleted and decrypted
    /// (organization items without edit permission, items in the trash and decryption failures have no move); `nil`
    /// otherwise. Code rows pass their cipher item (`totpCipherItem`).
    var folderMoveCipher: CipherListView? {
        guard case let .cipher(cipher, _) = itemType,
              cipher.id != nil,
              cipher.edit,
              cipher.deletedDate == nil,
              !cipher.isDecryptionFailure else {
            return nil
        }
        return cipher
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Move to folder") {
    Menu("Options") {
        VaultFolderPickerMenu(
            folders: [
                FolderView(id: "1", name: "Work", revisionDate: Date()),
                FolderView(id: "2", name: "Private", revisionDate: Date()),
            ],
            currentFolderId: "1",
            select: { _ in },
            newFolder: {},
        )
    }
}
#endif
