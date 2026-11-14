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
        VStack(alignment: .leading, spacing: 16) {
            if store.state.folders.isEmpty {
                empty
                    .background(Color(asset: SharedAsset.Colors.backgroundPrimary))
            } else {
                folders
            }
        }
        .navigationBar(title: Localizations.myFolders, titleDisplayMode: .inline)
        .overlay(alignment: .bottomTrailing) {
            addItemFloatingActionButton {
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
            additionalBottomPadding: FloatingActionButton.bottomOffsetPadding,
        )
    }

    // MARK: Private views

    /// The empty state for when the user doesn't have any folders yet.
    private var empty: some View {
        Text(Localizations.noFoldersToList)
            .styleGuide(.callout)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("NoFoldersLabel")
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
                Button {
                    guard let id = folder.id else { return }
                    store.send(.folderTapped(id: id))
                } label: {
                    HStack {
                        Label {
                            Text(folder.name)
                                .foregroundStyle(.primary)
                                .accessibilityIdentifier("FolderName")
                        } icon: {
                            Image(systemName: "folder")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("FolderCell")
            }
        }
        .listStyle(.insetGrouped)
        // Keep the last row clear of the floating add button.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: FloatingActionButton.bottomOffsetPadding)
        }
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
