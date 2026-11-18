// swiftlint:disable file_length

import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - SearchableVaultListView

/// The main view of the vault.
private struct SearchableVaultListView: View {
    // MARK: Properties

    /// A flag indicating if the search bar is focused.
    var isSearching: Bool

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The memoized tile/section split of the vault data.
    @SwiftUI.State private var splitCache = TileSplitCache()

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultListState, VaultListAction, VaultListEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// Whether the search results list is in edit mode (follows `isSelecting`, delayed when leaving).
    @SwiftUI.State private var listIsEditing = false

    var body: some View {
        // A ZStack with hidden children is used here so that opening and closing the
        // search interface does not reset the scroll position for the main vault
        // view, as would happen if we used an `if else` block here.
        //
        // Additionally, we cannot use an `.overlay()` on the main vault view to contain
        // the search interface since VoiceOver still reads the elements below the overlay,
        // which is not ideal.

        ZStack {
            let isSearching = isSearching
                || !store.state.searchText.isEmpty
                || !store.state.searchResults.isEmpty

            vault
                .hidden(isSearching)

            // ui-r8: the search list only exists while searching. Two scroll views in one screen confuse UIKit's
            // choice of the content scroll view for the large title, and the hidden one still diffed every change.
            if isSearching {
                search
            }
        }
        .animation(.easeInOut, value: store.state.organizationUserNotificationBannerData)
        .background(SharedAsset.Colors.backgroundPrimary.swiftUIColor.ignoresSafeArea())
        .toast(
            store.binding(
                get: \.toast,
                send: VaultListAction.toastShown,
            ),
            additionalBottomPadding: FloatingActionButton.bottomOffsetPadding,
        )
        .flightRecorderToastBanner(
            activeLog: store.state.flightRecorderToastBanner.activeLog,
            additionalBottomPadding: FloatingActionButton.bottomOffsetPadding,
            isVisible: store.bindingAsync(
                get: \.flightRecorderToastBanner.isToastBannerVisible,
                perform: { _ in .dismissFlightRecorderToastBanner },
            ),
            goToSettingsAction: {
                store.send(.navigateToFlightRecorderSettings)
            },
        )
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
        .animation(.default, value: isSearching)
    }

    // MARK: Private Properties

    /// A view that displays the empty vault interface.
    @ViewBuilder private var emptyVault: some View {
        VStack(spacing: 24) {
            Group {
                actionCard

                vaultFilterRow
            }

            Spacer()

            IllustratedMessageView(
                image: Asset.Images.Illustrations.items,
                title: Localizations.saveAndProtectYourData,
                message: Localizations
                    .theVaultProtectsMoreThanJustPasswordsStoreSecureLoginsIdsCardsAndNotesSecurelyHere,
            ) {
                Button {
                    store.send(.addItemPressed(.login))
                } label: {
                    HStack {
                        Image(decorative: SharedAsset.Icons.plus16)
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(Localizations.addLogin)
                    }
                }
                .buttonStyle(.primary(shouldFillWidth: false))
                .padding(.top, 8)
            }

            Spacer()
        }
        .animation(.easeInOut, value: store.state.importLoginsSetupProgress == .setUpLater)
        .animation(.easeInOut, value: store.state.importLoginsSetupProgress == .complete)
        .scrollView(centerContentVertically: true)
    }

    /// A view that displays the search interface, including search results, an empty search
    /// interface, and a message indicating that no results were found.
    @ViewBuilder private var search: some View {
        if store.state.searchText.isEmpty || !store.state.searchResults.isEmpty {
            List(selection: store.binding(get: \.selection, send: VaultListAction.selectionChanged)) {
                Section {
                    searchVaultFilterRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    ForEach(store.state.searchResults) { item in
                        vaultItemRow(
                            for: item,
                            isLastInSection: store.state.searchResults.last?.id == item.id,
                        )
                        .listRowInsets(EdgeInsets())
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
                }
            }
            // The list is rebuilt when the set of result rows changes (a delete removes rows while Select mode is on):
            // SwiftUI's incremental list diff crashed there ("Invalid number of items in section", reproducible).
            .id(store.state.searchResults.map(\.id))
            .environment(\.editMode, .constant(listIsEditing ? .active : .inactive))
            // Leaving Select mode in the same update as the removal of the deleted rows makes SwiftUI's list diff crash
            // ("Invalid number of items in section", measured), so edit mode is switched off a moment later.
            .task(id: store.state.isSelecting) {
                if store.state.isSelecting {
                    listIsEditing = true
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    listIsEditing = false
                }
            }
            .listStyle(.insetGrouped)
            .softBottomScrollEdge()
        } else {
            SearchNoResultsView {
                searchVaultFilterRow
            }
        }
    }

    /// Displays the vault filter for search row if the user is a member of any org.
    private var searchVaultFilterRow: some View {
        SearchVaultFilterRowView(
            hasDivider: true, store: store.child(
                state: \.searchVaultFilterState,
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

    /// A view that displays either the my vault or empty vault interface.
    ///
    /// ui-r8: wrapped in an `Equatable` boundary. Changes that do not touch what the vault list shows (toast, search
    /// text and results, bottom bar, profile menu, selection) no longer re-evaluate the list and its rows.
    @ViewBuilder private var vault: some View {
        EquatableContent(key: store.state.homeListKey) {
            LoadingView(state: store.state.loadingState) { sections in
                if sections.isEmpty {
                    emptyVault
                } else {
                    vaultContents(with: sections)
                        .readableContentWidth(760)
                }
            } errorView: { errorMessage in
                errorViewWithRetry(errorMessage: errorMessage)
            }
        }
        .equatable()
    }

    /// Displays the vault filter row if the user is a member of any.
    private var vaultFilterRow: some View {
        SearchVaultFilterRowView(
            hasDivider: false,
            store: store.child(
                state: \.vaultFilterState,
                mapAction: { action in
                    switch action {
                    case let .searchVaultFilterChanged(type):
                        .vaultFilterChanged(type)
                    }
                },
                mapEffect: nil,
            ),
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Private Methods

    /// A view that displays an error message and a retry button.
    ///
    /// - Parameter errorMessage: The error message to display.
    ///
    @ViewBuilder
    private func errorViewWithRetry(errorMessage: String) -> some View {
        VStack(spacing: 24) {
            Text(errorMessage)
                .foregroundStyle(SharedAsset.Colors.textPrimary.swiftUIColor)
                .styleGuide(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            AsyncButton {
                await store.perform(.tryAgainTapped)
            } label: {
                Text(Localizations.tryAgain)
            }
            .buttonStyle(
                .primary(
                    shouldFillWidth: false,
                ),
            )
        }
        .scrollView(centerContentVertically: true)
    }

    /// The vault as a native inset-grouped `List`: action card, vault filter, category tiles and one collapsible section per
    /// group of items. Rows get a "More" swipe action and pointer hover. The tiles and the item sections are
    /// `Equatable` subviews: a change that does not touch the vault data (toast, search text, bar) does not diff
    /// the (up to thousands of) rows again.
    ///
    /// - Parameter sections: The sections of the vault list to display.
    ///
    @ViewBuilder
    private func vaultContents(with sections: [VaultListSection]) -> some View {
        let (tileItems, listSections) = splitCache.split(sections)
        List {
            if store.state.activeActionCard != nil, store.state.activeActionCard != .introducingArchive {
                Section {
                    actionCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                vaultFilterRow
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if !tileItems.isEmpty {
                Section {
                    CategoryTilesView(items: tileItems) { item in
                        Task { await store.perform(.itemPressed(item)) }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            ForEach(listSections) { section in
                let isExpanded = !store.state.collapsedSectionIds.contains(section.id)
                Section {
                    if isExpanded {
                        ForEach(section.items) { item in
                            vaultItemRow(for: item, isLastInSection: section.items.last?.id == item.id)
                                .listRowInsets(EdgeInsets())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if case .cipher = item.itemType {
                                        Button {
                                            Task { await store.perform(.morePressed(item)) }
                                        } label: {
                                            Label(Localizations.moreOptions, systemImage: "ellipsis")
                                        }
                                        .tint(.gray)
                                    }
                                }
                        }
                    }
                } header: {
                    Button {
                        store.send(.sectionExpandToggled(sectionId: section.id, isExpanded: !isExpanded))
                    } label: {
                        HStack {
                            Text(section.name)
                            Spacer()
                            Text("\(section.items.count)")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.semibold))
                        }
                        .textCase(nil)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label).opacity(0.75)) // contrast (audit)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("SectionExpandButton_\(section.id)")
                    .accessibilityLabel("\(section.name), \(Localizations.xItems(section.items.count))")
                }
            }

            // Space below the last row so the floating action button never covers it.
            Section {
                Color.clear
                    .frame(height: FloatingActionButton.bottomOffsetPadding)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }
        }
        .listStyle(.insetGrouped)
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
        VaultListRowCell.make(
            for: item,
            isLastInSection: isLastInSection,
            isSelecting: listIsEditing,
            store: store,
            timeProvider: timeProvider,
        )
        .equatable()
    }
}

// MARK: - VaultListRowCell + VaultListState

extension VaultListRowCell {
    /// Creates a row of the vault or search list. No child `Store` is created: the row gets its state and closures.
    @MainActor
    static func make(
        for item: VaultListItem,
        isLastInSection: Bool,
        isSelecting: Bool = false,
        store: Store<VaultListState, VaultListAction, VaultListEffect>,
        timeProvider: any TimeProvider,
    ) -> VaultListRowCell {
        PassYPerf.rowBuildCount += 1
        let state = store.state
        return VaultListRowCell(
            state: VaultListItemRowState(
                iconBaseURL: state.iconBaseURL,
                hasPremium: state.hasPremium,
                isFromExtension: false,
                isSelecting: isSelecting,
                item: item,
                hasDivider: !isLastInSection,
                showWebIcons: state.showWebIcons,
            ),
            perform: { [weak store] effect in
                switch effect {
                case let .accessibilityMoreOptionsActionPressed(kind):
                    await store?.perform(.accessibilityMoreOptionsActionPressed(item, kind))
                case .morePressed:
                    await store?.perform(.morePressed(item))
                case .pressed:
                    await store?.perform(.itemPressed(item))
                }
            },
            send: { [weak store] action in
                switch action {
                case let .copyTOTPCode(code):
                    store?.send(.copyTOTPCode(code))
                }
            },
            timeProvider: timeProvider,
            onDelete: item.isCipherItem ? { [weak store] in Task { await store?.perform(.deleteItems([item])) } } : nil,
        )
    }
}

// MARK: - EquatableContent

/// A view whose body is only evaluated again when `key` changes (the closure is ignored by `==`).
struct EquatableContent<Key: Equatable, Content: View>: View, Equatable {
    /// What the content depends on.
    let key: Key

    /// The content.
    @ViewBuilder let content: () -> Content

    static func == (lhs: EquatableContent, rhs: EquatableContent) -> Bool { lhs.key == rhs.key }

    var body: some View { content() }
}

// MARK: - VaultListState + home list key

extension VaultListState {
    /// The state without everything the vault home list does not show. Two equal keys mean the same list.
    var homeListKey: VaultListState {
        var key = self
        key.flightRecorderToastBanner = FlightRecorderToastBannerState()
        key.folders = []
        key.isEligibleForAppReview = false
        key.isSelecting = false
        key.itemTypesUserCanCreate = []
        key.profileSwitcherState = .empty()
        key.searchResults = []
        key.searchText = ""
        key.searchVaultFilterType = .allVaults
        key.selection = []
        key.toast = nil
        key.url = nil
        return key
    }
}

// MARK: - TileSplitCache

/// Splits the vault sections into category tile items and list sections once per data change. `Array` equality
/// short-circuits when both arrays share their storage, so an unchanged vault costs O(1) per body pass.
final class TileSplitCache {
    private var sections: [VaultListSection]?
    private var result: ([VaultListItem], [VaultListSection]) = ([], [])

    func split(_ new: [VaultListSection]) -> ([VaultListItem], [VaultListSection]) {
        if let sections, sections == new { return result }
        var tileItems: [VaultListItem] = []
        var listSections: [VaultListSection] = []
        for section in new {
            var rest: [VaultListItem] = []
            rest.reserveCapacity(section.items.count)
            for item in section.items {
                if case let .group(group, _) = item.itemType, group.isCategoryTile {
                    tileItems.append(item)
                } else {
                    rest.append(item)
                }
            }
            if rest.count == section.items.count {
                listSections.append(section)
            } else if !rest.isEmpty {
                listSections.append(VaultListSection(id: section.id, items: rest, name: section.name))
            }
        }
        sections = new
        result = (tileItems, listSections)
        return result
    }
}

// MARK: - Action Cards

extension SearchableVaultListView {
    /// The active action card, rendered based on priority. Only one card is shown at a time.
    @ViewBuilder private var actionCard: some View {
        switch store.state.activeActionCard {
        case .importItems:
            ActionCard(
                title: Localizations.importSavedLogins,
                message: Localizations.importSavedLoginsDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.getStarted) {
                    store.send(.showImportLogins)
                },
                dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                    await store.perform(.dismissImportLoginsActionCard)
                },
            )
        case .introducingArchive:
            // Pass-Y does not show feature promotions.
            EmptyView()
        case let .organizationBanner(data):
            ActionCard(
                title: data.headerText,
                message: data.description,
                actionButtonState: data.buttonText.map { text in
                    ActionCard.ButtonState(title: text) {
                        await store.perform(.dismissOrganizationBanner(fromActionButton: true))
                    }
                },
                dismissButtonState: data.buttonText == nil
                    ? ActionCard.ButtonState(title: Localizations.dismiss) {
                        await store.perform(.dismissOrganizationBanner(fromActionButton: false))
                    }
                    : nil,
            ) {
                SharedAsset.Icons.informationCircle24.swiftUIImage
                    .foregroundStyle(SharedAsset.Colors.iconSecondary.swiftUIColor)
            }
        case .subscriptionNeedsAttention:
            ActionCard(
                title: Localizations.subscriptionNeedsAttention,
                message: Localizations.checkYourPlanForDetails,
                actionButtonState: ActionCard.ButtonState(title: Localizations.viewPlan) {
                    store.send(.viewPlan)
                },
            )
        case .upgradedToPremium:
            UpgradedToPremiumActionCardView(
                onDismiss: { await store.perform(.dismissUpgradedToPremiumActionCard) },
                onLearnMore: { store.send(.learnMoreAboutPremium) },
            )
        case .upgradeNeeded:
            ActionCard(
                title: Localizations.unlockAdvancedSecurityFeatures,
                message: Localizations.aPremiumPlanGivesYouMoreToolsDescriptionLong,
                actionButtonState: ActionCard.ButtonState(title: Localizations.learnMore) {
                    await store.perform(.upgradeToPremium)
                },
                dismissButtonState: ActionCard.ButtonState(title: Localizations.dismiss) {
                    await store.perform(.dismissPremiumUpgradeActionCard)
                },
            )
        case nil:
            EmptyView()
        }
    }
}

// MARK: - VaultListView

/// A view that allows the user to view a list of the items in their vault.
///
struct VaultListView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<VaultListState, VaultListAction, VaultListEffect>

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: any TimeProvider

    /// The window scene for requesting a review.
    var windowScene: UIWindowScene?

    /// Task running the vault list stream, managed manually so it is cancelled and restarted when
    /// the vault filter type changes.
    @SwiftUI.State private var vaultListTask: Task<Void, Never>?

    /// The shell model that owns the persistent bottom search field.
    @ObservedObject private var shell = PassYShellModel.shared

    var body: some View {
        ZStack {
            SearchableVaultListView(
                isSearching: shell.isEditing || !store.state.searchText.isEmpty,
                store: store,
                timeProvider: timeProvider,
            )
            .passYSearchTarget(
                id: ObjectIdentifier(store),
                isPushed: false,
                text: store.state.searchText,
                entries: addEntries,
                setText: { store.send(.searchTextChanged($0)) },
                setSearching: { store.send(.searchStateChanged(isSearching: $0)) },
            )
            .autocorrectionDisabled(true)
            .searchDebouncedTask(id: store.state.searchText) {
                await store.perform(.search(store.state.searchText))
            }
            .task {
                await store.perform(.search(store.state.searchText))
            }
            .onChange(of: store.state.searchVaultFilterType) { _ in
                Task { await store.perform(.search(store.state.searchText)) }
            }
            .refreshable { [weak store] in
                await store?.perform(.refreshVault)
            }
            if #unavailable(iOS 26) {
                profileSwitcher
            }
        }
        .navigationBar(title: store.state.navigationTitle, titleDisplayMode: .large)
        .toolbar {
            searchSelectToolbar
            PassYAvatarToolbarItem()
        }
        .task {
            await store.perform(.refreshAccountProfiles)
        }
        .onAppear { publishProfileMenu() }
        .onChange(of: store.state.profileSwitcherState) { _ in publishProfileMenu() }
        .task {
            await store.perform(.appeared)
        }
        .task {
            await store.perform(.streamAccountSetupProgress)
        }
        .task {
            await store.perform(.streamFlightRecorderLog)
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
        .onAppear { restartVaultListStream() }
        .onChange(of: store.state.vaultFilterType) { _ in restartVaultListStream() }
        .onDisappear {
            vaultListTask?.cancel()
            vaultListTask = nil
            // Opening a result ends editing in the bottom search bar; the search text is kept and the bar
            // shows its cancel button.
            shell.isEditing = false
            NotificationCenter.default.post(name: .vaultSearchResign, object: nil)
        }
        .onAppear {
            Task {
                await store.perform(.checkAppReviewEligibility)
            }
        }
        .onDisappear {
            store.send(.disappeared)
        }
        .requestReview(isEligible: store.state.isEligibleForAppReview, windowScene: windowScene) {
            store.send(.appReviewPromptShown)
        }
    }

    // MARK: Private methods

    /// The search results that are selected in Select mode.
    private var selectedSearchItems: [VaultListItem] {
        store.state.searchResults.filter { store.state.selection.contains($0.id) }
    }

    /// Select / Done for the search results and, in Select mode, Move and Delete (like the group lists).
    @ToolbarContentBuilder private var searchSelectToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            if shell.isEditing || !store.state.searchText.isEmpty,
               store.state.searchResults.contains(where: \.isCipherItem) {
                if store.state.isSelecting {
                    Menu {
                        Button(Localizations.folderNone) {
                            let items = selectedSearchItems
                            Task { await store.perform(.moveItems(items, folderId: nil)) }
                        }
                        ForEach(store.state.folders, id: \.id) { folder in
                            Button(folder.name) {
                                let items = selectedSearchItems
                                Task { await store.perform(.moveItems(items, folderId: folder.id)) }
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .disabled(store.state.selection.isEmpty)
                    .accessibilityLabel(Localizations.move)
                    .accessibilityIdentifier("SelectMoveButton")

                    Button(role: .destructive) {
                        let items = selectedSearchItems
                        Task { await store.perform(.deleteItems(items)) }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(store.state.selection.isEmpty)
                    .accessibilityLabel(Localizations.delete)
                    .accessibilityIdentifier("SelectDeleteButton")
                }
                Button(store.state.isSelecting ? Localizations.done : "Select") {
                    store.send(.setSelecting(!store.state.isSelecting))
                }
                .accessibilityIdentifier("SelectButton")
            }
        }
    }

    /// The "+" menu of the persistent bottom bar: the item types and a folder.
    private var addEntries: [PassYAddEntry] {
        var entries = store.state.itemTypesUserCanCreate.passYAddMenuOrdered.map { type in
            PassYAddEntry(
                id: "type-\(type.hashValue)",
                action: { store.send(.addItemPressed(type)) },
                symbol: type.passYAddMenuSymbol,
                title: type.localizedName,
            )
        }
        entries.append(PassYAddEntry(
            id: "folder",
            action: { store.send(.addFolder) },
            dividerBefore: true,
            symbol: "folder",
            title: Localizations.folder,
        ))
        return entries
    }

    /// Publishes the accounts and actions for the avatar menu that every top-level screen shows.
    private func publishProfileMenu() {
        let state = store.state.profileSwitcherState
        shell.profileMenu = PassYProfileMenuSource(
            accounts: state.accounts,
            activeAccountId: state.activeAccountId,
            activeProfile: state.activeAccountProfile,
            addAccount: { Task { await store.perform(.profileSwitcher(.addAccountPressed)) } },
            canLock: state.allowLockAndLogout && state.activeAccountProfile?.canBeLocked == true,
            lock: { account in Task { await store.perform(.profileSwitcher(.accessibility(.lock(account)))) } },
            select: { account in Task { await store.perform(.profileSwitcher(.accountPressed(account))) } },
            showsAddAccount: state.showsAddAccount,
            showsPlaceholder: state.showPlaceholderToolbarIcon,
            sync: { Task { await store.perform(.refreshVault) } },
        )
    }

    // MARK: Private properties

    /// A view that displays the ability to add or switch between account profiles
    @ViewBuilder private var profileSwitcher: some View {
        ProfileSwitcherView(
            store: store.child(
                state: { vaultListState in
                    vaultListState.profileSwitcherState
                },
                mapAction: { action in
                    .profileSwitcher(action)
                },
                mapEffect: { effect in
                    .profileSwitcher(effect)
                },
            ),
        )
    }

    // MARK: Private Methods

    /// Cancels the current vault list stream task and starts a new one for the active vault filter.
    private func restartVaultListStream() {
        vaultListTask?.cancel()
        vaultListTask = Task { await store.perform(.streamVaultList) }
    }
}

// MARK: Previews

#if DEBUG

#Preview("Loading") {
    NavigationView {
        VaultListView(
            store: Store(processor: StateProcessor(state: VaultListState())),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Error") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .error(
                            errorMessage: Localizations.weCouldntSyncYourVaultWithTheServerDescriptionLong,
                        ),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(loadingState: .data([])),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty - Import Logins") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        importLoginsSetupProgress: .incomplete,
                        loadingState: .data([]),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Empty - Subscription Attention") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        shouldShowSubscriptionAttentionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        name: "Example 2",
                                        type: .secureNote,
                                    ))!,
                                ],
                                name: "Favorites",
                            ),
                            VaultListSection(
                                id: "2",
                                items: [
                                    VaultListItem(id: "21", itemType: .group(.login, 123)),
                                    VaultListItem(id: "22", itemType: .group(.card, 25)),
                                    VaultListItem(id: "23", itemType: .group(.identity, 1)),
                                    VaultListItem(id: "24", itemType: .group(.secureNote, 0)),
                                    VaultListItem(id: "25", itemType: .group(.sshKey, 4)),
                                ],
                                name: "Types",
                            ),
                        ]),
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Upgraded to Premium") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowUpgradedToPremiumActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Upgrade to Premium") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowPremiumUpgradeActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Introducing Archive") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowArchiveOnboardingActionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Subscription Attention") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "1",
                                items: [
                                    VaultListItem(id: "11", itemType: .group(.login, 42)),
                                    VaultListItem(id: "12", itemType: .group(.card, 5)),
                                ],
                                name: "Types",
                            ),
                        ]),
                        shouldShowArchiveOnboardingActionCard: true,
                        shouldShowSubscriptionAttentionCard: true,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("My Vault - Collections") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([
                            VaultListSection(
                                id: "Collections",
                                items: [
                                    VaultListItem(
                                        id: "31",
                                        itemType: .group(
                                            .collection(id: "", name: "Design", organizationId: "1"),
                                            0,
                                        ),
                                    ),
                                    VaultListItem(
                                        id: "32",
                                        itemType: .group(
                                            .collection(id: "", name: "Engineering", organizationId: "1"),
                                            2,
                                        ),
                                    ),
                                ],
                                name: "Collections",
                            ),
                            VaultListSection(
                                id: "CollectionItems",
                                items: [
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                    .init(cipherListView: .fixture(
                                        id: UUID().uuidString,
                                        organizationId: "1",
                                        login: .fixture(username: "email@example.com"),
                                        name: "Example",
                                        subtitle: "email@example.com",
                                    ))!,
                                ],
                                name: "Items",
                            ),
                        ]),
                        organizations: [
                            Organization(
                                enabled: true,
                                id: "",
                                isProviderUser: false,
                                key: nil,
                                keyConnectorEnabled: false,
                                keyConnectorUrl: nil,
                                name: "Org",
                                permissions: Permissions(),
                                status: .confirmed,
                                type: .user,
                                useEvents: false,
                                usePolicies: true,
                                userIsManagedByOrganization: false,
                                usersGetPremium: false,
                            ),
                        ],
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("1 Search Result") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        profileSwitcherState: ProfileSwitcherState(
                            accounts: [],
                            activeAccountId: nil,
                            allowLockAndLogout: true,
                            isVisible: false,
                        ),
                        searchResults: [
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email@example.com"),
                                name: "Example",
                                subtitle: "email@example.com",
                            ))!,
                        ],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("3 Search Results") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        searchResults: [
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email@example.com"),
                                name: "Example",
                                subtitle: "email@example.com",
                            ))!,
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email2@example.com"),
                                name: "Example 2",
                                subtitle: "email2@example.com",
                            ))!,
                            .init(cipherListView: .fixture(
                                id: UUID().uuidString,
                                login: .fixture(username: "email3@example.com"),
                                name: "Example 3",
                                subtitle: "email3@example.com",
                            ))!,
                        ],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("No Search Results") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        searchResults: [],
                        searchText: "Exam",
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Profile Switcher Visible: Single Account") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        profileSwitcherState: .singleAccount,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}

#Preview("Profile Switcher Visible: Multi Account") {
    NavigationView {
        VaultListView(
            store: Store(
                processor: StateProcessor(
                    state: VaultListState(
                        loadingState: .data([]),
                        profileSwitcherState: .dualAccounts,
                    ),
                ),
            ),
            timeProvider: PreviewTimeProvider(),
        )
    }
}
#endif

// MARK: - Soft bottom scroll edge

extension View {
    /// Fades list content out under the floating bottom bar (iOS 26 scroll edge effect) so rows do not shine through.
    @ViewBuilder
    func softBottomScrollEdge() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }
}
