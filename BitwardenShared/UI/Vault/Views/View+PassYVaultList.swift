import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - Vault rows

extension View {
    /// A row of the vault, group and search lists: the row brings its own 16 pt side margins (also used outside lists),
    /// so the list row has no insets; cipher rows get the trailing swipe actions (Delete, More menu).
    ///
    /// - Parameters:
    ///   - item: The row's item.
    ///   - hasPremium: Whether the account has Premium (gates Copy TOTP).
    ///   - delete: Starts the (confirmed) delete of the item.
    ///   - perform: Performs one of the item's more-options actions.
    ///
    func passYVaultRow(
        _ item: VaultListItem,
        hasPremium: Bool,
        delete: @escaping () -> Void,
        perform: @escaping (MoreOptionsActionKind) -> Void,
    ) -> some View {
        listRowInsets(EdgeInsets())
            .vaultRowSwipeActions(for: item, hasPremium: hasPremium, delete: delete, perform: perform)
    }

    /// The edit mode of a list with a Select mode (group pages, the home's search results). Leaving Select mode in the
    /// same update as the removal of deleted rows makes SwiftUI's list diff crash ("Invalid number of items in
    /// section", measured), so the list leaves edit mode half a second after `isSelecting` turns off.
    ///
    /// - Parameters:
    ///   - isSelecting: Whether Select mode is on (the store's state).
    ///   - listIsEditing: The list's own edit state (a `@State` of the view), also given to the rows.
    ///
    func passYSelectEditMode(isSelecting: Bool, listIsEditing: Binding<Bool>) -> some View {
        environment(\.editMode, .constant(listIsEditing.wrappedValue ? .active : .inactive))
            .task(id: isSelecting) {
                if isSelecting {
                    listIsEditing.wrappedValue = true
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    listIsEditing.wrappedValue = false
                }
            }
    }
}

// MARK: - PassYSelectModeButtons

/// The toolbar buttons of a list with a Select mode (Apple Passwords): Select / Done and, in Select mode, Move (a
/// folder menu) and Delete. Used by the group pages and the home's search results.
struct PassYSelectModeButtons: View {
    /// Whether Select mode is on.
    let isSelecting: Bool

    /// Whether no item is selected (Move and Delete are disabled).
    let selectionIsEmpty: Bool

    /// Whether moving is not possible at all (e.g. the trash).
    var moveIsDisabled = false

    /// The folders offered by Move.
    let folders: [FolderView]

    /// Moves the selected items to the folder (`nil`: no folder).
    let move: (_ folderId: String?) -> Void

    /// Deletes the selected items (with confirmation).
    let delete: () -> Void

    /// Turns Select mode on or off.
    let toggle: () -> Void

    var body: some View {
        if isSelecting {
            Menu {
                Button(Localizations.folderNone) { move(nil) }
                ForEach(folders, id: \.id) { folder in
                    Button(folder.name) { move(folder.id) }
                }
            } label: {
                Image(systemName: "folder")
            }
            .disabled(selectionIsEmpty || moveIsDisabled)
            .accessibilityLabel(Localizations.move)
            .accessibilityIdentifier("SelectMoveButton")

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .disabled(selectionIsEmpty)
            .accessibilityLabel(Localizations.delete)
            .accessibilityIdentifier("SelectDeleteButton")
        }
        Button(isSelecting ? Localizations.done : "Select", action: toggle)
            .accessibilityIdentifier("SelectButton")
    }
}
