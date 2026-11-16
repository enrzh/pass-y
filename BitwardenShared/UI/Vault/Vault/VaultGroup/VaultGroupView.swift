import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - VaultGroupView

/// A view that displays the items in a single vault group.
struct VaultGroupView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The GroupSearchDelegate used to bridge UIKit to SwiftUI
    var searchHandler: VaultGroupSearchHandler?

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultGroupState, VaultGroupAction, VaultGroupEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// Whether the system shows "N Items" as a navigation subtitle (iOS 26). Before that the count is a plain
    /// secondary text row at the top of the list (`ItemCountHeader`).
    var supportsNavigationSubtitle: Bool = {
        if #available(iOS 26, *) { true } else { false }
    }()

    /// Whether the list is in Select mode (Apple Passwords).
    private var isSelecting: Bool { store.state.isSelecting }

    // MARK: View

    var body: some View {
        content
            .toolbar { selectToolbar }
            .passYSearchTarget(
                id: ObjectIdentifier(store),
                isPushed: true,
                text: store.state.searchText,
                entries: addEntries,
                setText: { store.send(.searchTextChanged($0)) },
                setSearching: { store.send(.searchStateChanged(isSearching: $0)) },
            )
            .navigationTitle(store.state.group.navigationTitle)
            .passYItemCountSubtitle(supportsNavigationSubtitle ? itemCountSubtitle : nil)
            .navigationBarTitleDisplayMode(.inline)
            .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor.ignoresSafeArea())
            .task {
                await store.perform(.appeared)
            }
            .task {
                await store.perform(.streamOrganizations)
            }
            .task {
                await store.perform(.streamShowWebIcons)
            }
            .task {
                await store.perform(.streamSyncComplete)
            }
            .toast(
                store.binding(
                    get: \.toast,
                    send: VaultGroupAction.toastShown,
                ),
                additionalBottomPadding: FloatingActionButton.bottomOffsetPadding,
            )
    }

    // MARK: Private

    /// All cipher items currently shown (not searching).
    private var allItems: [VaultListItem] {
        guard case let .data(sections) = store.state.loadingState else { return [] }
        return sections.flatMap(\.items)
    }

    /// "N Items" under the title (iOS 26) or as the first list row (earlier systems), like Apple Passwords.
    private var itemCountSubtitle: String? {
        guard !store.state.isSearching, case .data = store.state.loadingState, !allItems.isEmpty else { return nil }
        return Localizations.xItems(allItems.count).replacingOccurrences(of: "items", with: "Items")
    }

    /// The selected items.
    private var selectedItems: [VaultListItem] {
        allItems.filter { store.state.selection.contains($0.id) }
    }

    /// Select / Done and, in Select mode, Move and Delete.
    @ToolbarContentBuilder private var selectToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            selectBarContent
        }
    }

    @ViewBuilder private var selectBarContent: some View {
        if !store.state.isSearching, !allItems.isEmpty, !isCipherlessGroup {
            if isSelecting {
                Menu {
                    Button(Localizations.folderNone) {
                        let items = selectedItems
                        Task { await store.perform(.moveItems(items, folderId: nil)) }
                    }
                    ForEach(store.state.folders, id: \.id) { folder in
                        Button(folder.name) {
                            let items = selectedItems
                            Task { await store.perform(.moveItems(items, folderId: folder.id)) }
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .disabled(store.state.selection.isEmpty || store.state.group == .trash)
                .accessibilityLabel(Localizations.move)
                .accessibilityIdentifier("SelectMoveButton")

                Button(role: .destructive) {
                    let items = selectedItems
                    // Select mode stays: the processor ends it after a complete delete, keeps failed items
                    // selected, and a cancelled confirmation changes nothing.
                    Task { await store.perform(.deleteItems(items)) }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.state.selection.isEmpty)
                .accessibilityLabel(Localizations.delete)
                .accessibilityIdentifier("SelectDeleteButton")
            }
            Button(isSelecting ? Localizations.done : "Select") {
                store.send(.setSelecting(!isSelecting))
            }
            .accessibilityIdentifier("SelectButton")
        }
    }

    /// Groups made only of non-cipher rows (e.g. verification codes) have no Select mode.
    private var isCipherlessGroup: Bool {
        !allItems.contains { if case .cipher = $0.itemType { true } else { false } }
    }

    /// The "+" menu of the persistent bottom bar for this group.
    private var addEntries: [PassYAddEntry] {
        guard let type = store.state.newItemButtonType else { return [] }
        switch type {
        case .button:
            return [PassYAddEntry(
                id: "group-add",
                action: { store.send(.addItemPressed(nil)) },
                symbol: "plus",
                title: store.state.addItemButtonTitle,
            )]
        case .menu:
            return store.state.itemTypesUserCanCreate.passYAddMenuOrdered.map { type in
                PassYAddEntry(
                    id: "type-\(type.hashValue)",
                    action: { store.send(.addItemPressed(type)) },
                    symbol: type.passYAddMenuSymbol,
                    title: type.localizedName,
                )
            }
        }
    }

    /// The action card for Premium subscription ended for archive.
    @ViewBuilder private var archivePremiumSubscriptionEndedCard: some View {
        if store.state.showArchivePremiumSubscriptionEndedCard {
            ActionCard(
                title: Localizations.yourPremiumSubscriptionEnded,
                message: Localizations.yourPremiumSubscriptionEndedArchiveDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.restartPremium) {
                    store.send(.restartPremiumSubscription)
                },
            )
        }
    }

    @ViewBuilder private var content: some View {
        searchOrGroup
            .readableContentWidth(760)
            .onChange(of: store.state.url) { newValue in
                guard let url = newValue else { return }
                openURL(url)
                store.send(.clearURL)
            }
            .searchDebouncedTask(id: store.state.searchText) {
                await store.perform(.search(store.state.searchText))
            }
            .task {
                await store.perform(.search(store.state.searchText))
            }
            .onChange(of: store.state.searchVaultFilterType) { _ in
                Task { await store.perform(.search(store.state.searchText)) }
            }
            .animation(.default, value: store.state.isSearching)
    }

    /// A view that displays an empty state for this vault group.
    @ViewBuilder private var emptyView: some View {
        IllustratedMessageView(
            image: Asset.Images.Illustrations.noItems.swiftUIImage,
            title: store.state.noItemsTitle,
            message: store.state.noItemsString,
        ) {
            if let newItemButtonType = store.state.newItemButtonType {
                let newItemLabel = Label(
                    store.state.addItemButtonTitle,
                    image: SharedAsset.Icons.plus16.swiftUIImage,
                )

                Group {
                    switch newItemButtonType {
                    case .button:
                        Button {
                            store.send(.addItemPressed(nil))
                        } label: {
                            newItemLabel
                        }
                        .buttonStyle(.primary(shouldFillWidth: false))
                    case .menu:
                        Menu {
                            ForEach(store.state.itemTypesUserCanCreate, id: \.hashValue) { type in
                                Button(type.localizedName) {
                                    store.send(.addItemPressed(type))
                                }
                            }
                        } label: {
                            newItemLabel
                        }
                    }
                }
                .accessibilityIdentifier("AddItemButton")
                .buttonStyle(.primary(shouldFillWidth: false))
            }
        }
        .scrollView(centerContentVertically: true)
    }

    /// A view that displays either the group or empty interface.
    @ViewBuilder private var groupItems: some View {
        LoadingView(state: store.state.loadingState) { items in
            if items.isEmpty {
                emptyView
            } else {
                groupView(with: items)
            }
        }
    }

    /// A view that displays the search interface, including search results, an empty search
    /// interface, and a message indicating that no results were found.
    ///
    @ViewBuilder private var searchContent: some View {
        if store.state.searchText.isEmpty || !store.state.searchResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    searchVaultFilterRow

                    ForEach(store.state.searchResults) { item in
                        vaultItemRow(
                            for: item,
                            isLastInSection: store.state.searchResults.last == item,
                        )
                        .background(SharedAsset.Colors.backgroundSecondary.swiftUIColor)
                    }
                }
            }
        } else {
            SearchNoResultsView {
                searchVaultFilterRow
            }
        }
    }

    /// The group content or search view.
    ///
    ///  If `store.state.isSearching` is `true`:  The view shows the `searchContentView`,
    ///     else: The view shows the `groupItemsView`.
    ///
    @ViewBuilder private var searchOrGroup: some View {
        if store.state.isSearching {
            searchContent
        } else {
            groupItems
        }
    }

    /// Displays the vault filter for search row if the user is a member of any org.
    ///
    private var searchVaultFilterRow: some View {
        SearchVaultFilterRowView(
            hasDivider: true, store: store.child(
                state: \.vaultFilterState,
                mapAction: { action in
                    switch action {
                    case let .searchVaultFilterChanged(type):
                        .searchVaultFilterChanged(type)
                    }
                },
                mapEffect: nil,
            ),
        )
    }

    // MARK: Private Methods

    /// A view that displays a list of the sections within this vault group.
    ///
    @ViewBuilder
    private func groupView(with sections: [VaultListSection]) -> some View {
        List(selection: store.binding(get: \.selection, send: VaultGroupAction.selectionChanged)) {
            if !supportsNavigationSubtitle, let count = itemCountSubtitle {
                Text(count)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("ItemCountHeader")
            }

            if store.state.showArchivePremiumSubscriptionEndedCard {
                archivePremiumSubscriptionEndedCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        vaultItemRow(for: item, isLastInSection: section.items.last == item)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .tag(item.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if case .cipher = item.itemType {
                                    Button(role: .destructive) {
                                        Task { await store.perform(.deleteItems([item])) }
                                    } label: {
                                        Label(Localizations.delete, systemImage: "trash")
                                    }
                                    Button {
                                        Task { await store.perform(.morePressed(item)) }
                                    } label: {
                                        Label(Localizations.moreOptions, systemImage: "ellipsis")
                                    }
                                    .tint(.gray)
                                }
                            }
                    }
                } header: {
                    if itemCountSubtitle == nil {
                        Text(section.name)
                    }
                }
            }

            Section {
                Color.clear
                    .frame(height: FloatingActionButton.bottomOffsetPadding)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
        .softBottomScrollEdge()
    }

    /// Creates a row in the list for the provided item.
    ///
    /// - Parameters:
    ///   - item: The `VaultListItem` to use when creating the view.
    ///   - isLastInSection: A flag indicating if this item is the last one in the section.
    ///
    @ViewBuilder
    private func vaultItemRow(for item: VaultListItem, isLastInSection: Bool = false) -> some View {
        VaultListItemRowView(
            store: store.child(
                state: { state in
                    VaultListItemRowState(
                        iconBaseURL: state.iconBaseURL,
                        hasPremium: state.hasPremium,
                        item: item,
                        hasDivider: !isLastInSection,
                        showWebIcons: state.showWebIcons,
                    )
                },
                mapAction: { action in
                    switch action {
                    case let .copyTOTPCode(code):
                        .copyTOTPCode(code)
                    }
                },
                mapEffect: { effect in
                    switch effect {
                    case let .accessibilityMoreOptionsActionPressed(kind):
                        .accessibilityMoreOptionsActionPressed(item, kind)
                    case .morePressed:
                        .morePressed(item)
                    case .pressed:
                        .itemPressed(item)
                    }
                },
            ),
            timeProvider: timeProvider,
            onDelete: item.isCipherItem ? { Task { await store.perform(.deleteItems([item])) } } : nil,
        )
    }
}

// MARK: - Item count subtitle

extension View {
    /// Shows "N Items" under the navigation title (iOS 26 `navigationSubtitle`, like Apple Passwords).
    @ViewBuilder
    func passYItemCountSubtitle(_ text: String?) -> some View {
        if #available(iOS 26, *) {
            navigationSubtitle(text ?? "")
        } else {
            self
        }
    }
}

extension VaultListItem {
    /// Whether this row is a cipher (rather than a group or TOTP row).
    var isCipherItem: Bool {
        if case .cipher = itemType { return true }
        return false
    }
}

// MARK: Previews

#if DEBUG
#Preview("Loading") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        loadingState: .loading(nil),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        loadingState: .data([]),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Logins") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        group: .login,
                        loadingState: .data(
                            [
                                .init(
                                    id: "Items",
                                    items: [
                                        .init(cipherListView: .fixture(
                                            id: "1",
                                            login: .fixture(
                                                username: "email@example.com",
                                            ),
                                            name: "Example",
                                        ))!,
                                        .init(cipherListView: .fixture(
                                            id: "2",
                                            login: .fixture(
                                                username: "email2@example.com",
                                            ),
                                            name: "Example 2",
                                        ))!,
                                    ],
                                    name: "Items",
                                ),
                            ],
                        ),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Trash") {
    NavigationView {
        VaultGroupView(
            store: Store(
                processor: StateProcessor(
                    state: VaultGroupState(
                        group: .trash,
                        loadingState: .data([]),
                        searchVaultFilterType: .allVaults,
                        vaultFilterType: .allVaults,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}
#endif
