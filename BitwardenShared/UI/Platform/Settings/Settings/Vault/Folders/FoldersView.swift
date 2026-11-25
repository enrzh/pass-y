import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - FoldersView

/// A view that allows users to view their folders.
///
struct FoldersView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<FoldersState, FoldersAction, FoldersEffect>

    // MARK: View

    var body: some View {
        // One list from the first frame; the empty message lies on top of the empty list (no swap of views).
        folders
            .overlay {
                if store.state.folders.isEmpty {
                    empty
                        .passYEmptyListState()
                }
            }
        .navigationTitle(Localizations.myFolders)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            addToolbarItem {
                store.send(.add)
            }
        }
        .task {
            await store.perform(.streamFolders)
        }
        .toast(
            store.binding(
                get: \.toast,
                send: FoldersAction.toastShown,
            ),
        )
    }

    // MARK: Private views

    /// The empty state for when the user doesn't have any folders yet.
    private var empty: some View {
        PassYEmptyState(Localizations.noFoldersToList, systemImage: "folder", identifier: "NoFoldersLabel")
    }

    /// The section listing all the user's folders.
    private var folders: some View {
        List {
            ForEach(
                store.state.folders.sorted { first, second in
                    if first.name.localizedStandardCompare(second.name) == .orderedSame {
                        first.id?.localizedStandardCompare(second.id ?? "") == .orderedAscending
                    } else {
                        first.name.localizedStandardCompare(second.name) == .orderedAscending
                    }
                },
                id: \.id,
            ) { folder in
                PassYRow(title: .init(text: folder.name, identifier: "FolderName"), showsDisclosure: true) {
                    PassYIconTile(systemImage: "folder.fill", tint: .blue)
                }
                .passYRowButton(identifier: "FolderCell") {
                    guard let id = folder.id else { return }
                    store.send(.folderTapped(id: id))
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
                .listRowInsets(EdgeInsets())
            }
        }
        .passYCardList(reservesBottomBarSpace: false)
        .passYReadableWidth()
    }
}

#if DEBUG
#Preview {
    FoldersView(
        store: Store(
            processor: StateProcessor(
                state: .init(
                    folders: (1 ... 12).map { id in
                        .init(
                            id: String(id),
                            name: "Test Folder",
                            revisionDate: .now,
                        )
                    },
                ),
            ),
        ),
    )
}
#endif
