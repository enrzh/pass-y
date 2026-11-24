import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - Card list

extension View {
    /// The list style of every Pass-Y list page (vault home, group pages, search results, Send, folders): an
    /// inset-grouped list whose sections are rounded cards on the grouped page colour.
    ///
    /// The list keeps the system background: hiding it (`scrollContentBackground`) on the vault list made SwiftUI
    /// rebuild the visible rows on unrelated state changes such as a toast
    /// (`VaultListPerfTests.test_unrelatedChanges_doNotRebuildRows`). An empty list's message uses
    /// `passYEmptyListState()` instead.
    ///
    /// - Parameter reservesBottomBarSpace: Whether the list keeps room below its last row for the floating bottom bar
    ///   (a content margin, not a spacer row: a spacer row drew a stray separator line below short lists) and fades
    ///   its content softly under the bar.
    ///
    func passYCardList(reservesBottomBarSpace: Bool = true) -> some View {
        listStyle(.insetGrouped)
            .modifier(PassYBottomBarScrollSpace(isEnabled: reservesBottomBarSpace))
    }

    /// The empty-state message laid over an empty list: centered, on the grouped page colour. An empty grouped list
    /// draws an almost white background instead of the grouped page colour, which showed as a light band above the
    /// bottom bar on an empty folder page; the message covers it with the page colour.
    func passYEmptyListState() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    /// Gives a native `Form` the grouped page colour so its cards stay visible (also inside sheets).
    func passYGroupedBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }

    /// Starts the system row separator at this view's leading edge (plus `offset`): the text column of a row, so the
    /// line does not run under the icon (Apple Passwords).
    func passYListSeparatorLeading(_ offset: CGFloat = 0) -> some View {
        alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + offset }
    }

    /// Room below the last row of a list for the floating bottom bar. A content margin, not a spacer row: a spacer row
    /// drew a stray separator line in the empty area below short lists.
    func passYBottomBarContentMargin() -> some View {
        contentMargins(.bottom, FloatingActionButton.bottomOffsetPadding, for: .scrollContent)
    }

    /// Fades list content out under the floating bottom bar (scroll edge effect) so rows do not shine through.
    func softBottomScrollEdge() -> some View {
        scrollEdgeEffectStyle(.soft, for: .bottom)
    }
}

/// The bottom bar room and soft scroll edge of `passYCardList`.
private struct PassYBottomBarScrollSpace: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .passYBottomBarContentMargin()
                .softBottomScrollEdge()
        } else {
            content
        }
    }
}

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
