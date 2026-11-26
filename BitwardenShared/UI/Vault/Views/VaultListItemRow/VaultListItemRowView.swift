import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - VaultListItemRowView

/// A row of a vault list (`VaultListItem`): the adapter from the item to the Pass-Y row components. Ciphers and groups
/// are a `PassYRow` (icon tile, name, subtitle, quiet badges, chevron), codes a `PassYCodeRow` (a tap copies the
/// code). Used by the vault home, group pages, search results and the autofill / item selection lists.
///
/// Identifiers kept for the UI tests: the row button `VaultListItemRowButton`, `CipherNameLabel`,
/// `CipherSubTitleLabel`, `CipherFido2CredentialRpIdLabel`, `CipherInCollectionIcon`, `CipherWithAttachmentsIcon`,
/// `CipherDisclosureChevron`, `GroupNameLabel`, `GroupSubTitleLabel`, `GroupCountLabel` and the icon identifiers.
struct VaultListItemRowView: View {
    // MARK: Properties

    /// Where the row reads its state from and sends actions and effects to. Either a `Store` (extension lists,
    /// previews, tests) or plain values and closures (the vault lists: no child `Store` per row and per body pass).
    let store: Source

    /// The `TimeProvider` used to calculate TOTP expiration (kept for the callers; the countdown reads the page's
    /// `PassYCountdownClock`).
    var timeProvider: (any TimeProvider)?

    /// Optional delete handler; when set the context menu offers "Delete".
    var onDelete: (() -> Void)?

    /// Counts code copies (drives the success haptic).
    @SwiftUI.State private var copyCount = 0

    // MARK: Types

    /// The state and the way back to the processor of a row.
    struct Source {
        /// Reads the current state.
        let stateProvider: () -> VaultListItemRowState

        /// Performs an effect.
        let performEffect: (VaultListItemRowEffect) async -> Void

        /// Sends an action.
        let sendAction: (VaultListItemRowAction) -> Void

        /// The current state.
        var state: VaultListItemRowState { stateProvider() }

        /// Performs an effect.
        func perform(_ effect: VaultListItemRowEffect) async { await performEffect(effect) }

        /// Sends an action.
        func send(_ action: VaultListItemRowAction) { sendAction(action) }
    }

    // MARK: Initialization

    /// Creates a row that follows a `Store`.
    init(
        store: Store<VaultListItemRowState, VaultListItemRowAction, VaultListItemRowEffect>,
        timeProvider: (any TimeProvider)? = nil,
        onDelete: (() -> Void)? = nil,
    ) {
        self.store = Source(
            stateProvider: { store.state },
            performEffect: { await store.perform($0) },
            sendAction: { store.send($0) },
        )
        self.timeProvider = timeProvider
        self.onDelete = onDelete
    }

    /// Creates a row from plain values and closures (no `Store` object per row).
    init(
        state: VaultListItemRowState,
        perform: @escaping (VaultListItemRowEffect) async -> Void,
        send: @escaping (VaultListItemRowAction) -> Void,
        timeProvider: (any TimeProvider)? = nil,
        onDelete: (() -> Void)? = nil,
    ) {
        store = Source(stateProvider: { state }, performEffect: perform, sendAction: send)
        self.timeProvider = timeProvider
        self.onDelete = onDelete
    }

    // MARK: View

    var body: some View {
        #if DEBUG
        let _ = { PassYPerf.rowBodyCount += 1 }()
        #endif
        let state = store.state
        content(state)
            // The side margin stays outside the row button (see `passYRowButton`).
            .padding(.horizontal, PassYDesign.Spacing.large)
            .overlay(alignment: .bottom) {
                // Rows outside a `List` (extension lists) draw their own hairline; lists use the system separators.
                if state.hasDivider {
                    Divider()
                        .padding(
                            .leading,
                            PassYDesign.Spacing.large + PassYDesign.IconSize.row + PassYDesign.Spacing.medium,
                        )
                }
            }
        #if DEBUG
            .onAppear { PassYPerf.rowAppeared(state.item.id) }
        #endif
            .contextMenu { contextMenuItems(state) }
            .sensoryFeedback(.success, trigger: copyCount)
    }

    // MARK: Private

    /// The row for the item type.
    @ViewBuilder
    private func content(_ state: VaultListItemRowState) -> some View {
        switch state.item.itemType {
        case let .cipher(cipherItem, _):
            cipherRow(cipherItem, state: state)
        case let .group(group, count):
            groupRow(group, count: count, state: state)
        case let .totp(name, model):
            codeRow(name: name, model: model, state: state)
        }
    }

    /// The icon tile of the row.
    private func tile(_ state: VaultListItemRowState) -> some View {
        VaultItemIconTile(item: state.item, iconBaseURL: state.iconBaseURL, showWebIcons: state.showWebIcons)
    }

    /// Opens the item (cipher and group rows; code rows that cannot be copied).
    private func press() {
        #if DEBUG
        PassYPerf.beginTap()
        #endif
        Task { await store.perform(.pressed) }
    }

    /// A cipher row: name, passkey domain and subtitle, quiet badges (favourite, shared, attachments), chevron.
    private func cipherRow(_ cipherItem: CipherListView, state: VaultListItemRowState) -> some View {
        PassYRow(
            title: .init(text: cipherItem.name, identifier: "CipherNameLabel"),
            subtitles: [
                state.item.shouldShowFido2CredentialRpId
                    ? .make(state.item.fido2CredentialRpId, identifier: "CipherFido2CredentialRpIdLabel") : nil,
                .make(state.item.subtitle, identifier: "CipherSubTitleLabel"),
            ],
            showsDisclosure: !state.isFromExtension && !cipherItem.isDecryptionFailure,
            disclosureIdentifier: "CipherDisclosureChevron",
        ) {
            tile(state)
        } titleAccessory: {
            CipherRowBadges(
                favorite: cipherItem.favorite,
                shared: cipherItem.organizationId != nil,
                attachments: cipherItem.attachments > 0,
            )
        }
        .passYRowButton(identifier: "VaultListItemRowButton", action: press)
        .accessibilityActions {
            ForEach(moreOptionsKinds(state), id: \.localizedName) { kind in
                Button(kind.localizedName) {
                    Task { await store.perform(.accessibilityMoreOptionsActionPressed(kind)) }
                }
            }
        }
        .allowsHitTesting(!state.isSelecting)
    }

    /// A group row (folder, collection, type, trash ...): name, item count (or a lock for Premium groups), chevron.
    private func groupRow(_ group: VaultListGroup, count: Int, state: VaultListItemRowState) -> some View {
        PassYRow(
            title: .init(text: group.name, identifier: "GroupNameLabel"),
            subtitles: [.make(state.item.subtitle, identifier: "GroupSubTitleLabel")],
            showsDisclosure: !state.isFromExtension,
        ) {
            tile(state)
        } trailing: {
            if state.item.accessoryIcon != nil {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } else {
                Text("\(count)")
                    .passYFont(.rowValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("GroupCountLabel")
            }
        }
        .passYRowButton(identifier: "VaultListItemRowButton", action: press)
        .allowsHitTesting(!state.isSelecting)
    }

    /// A code row: a tap copies the code (opens the item when the code needs the master password, or picks it in an
    /// extension list).
    private func codeRow(name: String, model: VaultListTOTP, state: VaultListItemRowState) -> some View {
        let code = model.requiresMasterPassword ? nil : model.totpCode.code
        let account = model.cipherListView.type.loginListView?.username
        let copies = code != nil && state.showTotpCopyButton && !state.isFromExtension
        let period = Int(model.totpCode.period)
        return PassYCodeRow(name: name, account: account, code: code, period: period) {
            tile(state)
        }
        .passYRowButton(identifier: "VaultListItemRowButton") {
            if copies, let code {
                copy(code)
            } else {
                press()
            }
        }
        .modifier(CodeRowAccessibility(name: name, account: account, code: code, period: period))
        .accessibilityHint(copies ? Localizations.copyTotp : "")
        .allowsHitTesting(!state.isSelecting)
    }

    /// Copies a code (the processor shows the toast, the row plays the success haptic).
    private func copy(_ code: String) {
        store.send(.copyTOTPCode(code))
        copyCount += 1
    }

    /// The long-press menu: the item options of a cipher row; Copy, View, Edit and Move to folder for a code row.
    @ViewBuilder
    private func contextMenuItems(_ state: VaultListItemRowState) -> some View {
        switch state.item.itemType {
        case let .totp(_, model):
            if !state.isFromExtension {
                if !model.requiresMasterPassword, state.showTotpCopyButton {
                    Button {
                        copy(model.totpCode.code)
                    } label: {
                        Label(Localizations.copy, systemImage: "doc.on.doc")
                    }
                }
                Button {
                    Task { await store.perform(.pressed) }
                } label: {
                    Label(Localizations.view, systemImage: "eye")
                }
                Button {
                    Task { await store.perform(.accessibilityMoreOptionsActionPressed(.edit)) }
                } label: {
                    Label(Localizations.edit, systemImage: "pencil")
                }
                VaultMoveToFolderMenu(item: state.item.totpCipherItem)
            }
        default:
            VaultItemOptionsMenuContent(
                kinds: moreOptionsKinds(state),
                item: state.isFromExtension ? nil : state.item,
                onSelect: { kind in Task { await store.perform(.accessibilityMoreOptionsActionPressed(kind)) } },
                onDelete: onDelete,
            )
        }
    }

    /// The more-options action kinds of this row (VoiceOver actions and the context menu), empty in an extension.
    private func moreOptionsKinds(_ state: VaultListItemRowState) -> [MoreOptionsActionKind] {
        state.isFromExtension ? [] : state.item.moreOptionsActionKinds(hasPremium: state.hasPremium)
    }
}

// MARK: - CipherRowBadges

/// The quiet badges after a cipher name (favourite, shared, attachments), each shown unless switched off in Customize
/// (`passYBadgeOptions`). Only this view reads the option, so the row itself is not evaluated again for it.
private struct CipherRowBadges: View {
    let favorite: Bool
    let shared: Bool
    let attachments: Bool

    @Environment(\.passYBadgeOptions) private var options

    var body: some View {
        if favorite, options.favorite {
            PassYBadge(
                systemImage: "star.fill",
                tint: .yellow,
                label: Localizations.favorite,
                identifier: "CipherFavoriteIcon",
            )
        }
        if shared, options.shared {
            PassYBadge(systemImage: "person.2.fill", label: Localizations.shared, identifier: "CipherInCollectionIcon")
        }
        if attachments, options.attachments {
            PassYBadge(
                systemImage: "paperclip",
                label: Localizations.attachments,
                identifier: "CipherWithAttachmentsIcon",
            )
        }
    }
}

// MARK: - CodeRowAccessibility

/// The spoken label of a code row: name, account, the code character by character and the seconds left. It reads the
/// page's countdown clock, so only this modifier (not the row) is evaluated again every second.
private struct CodeRowAccessibility: ViewModifier {
    let name: String
    let account: String?
    let code: String?
    let period: Int

    @Environment(\.passYCountdownClock) private var clock

    func body(content: Content) -> some View {
        let seconds = PassYCountdown(period: period, date: clock?.now ?? Date()).secondsRemaining
        content
            .accessibilityLabel(PassYOneTimeCode.accessibilityLabel(
                name: name,
                account: account,
                code: code,
                secondsRemaining: seconds,
            ))
    }
}

// MARK: - VaultListRowCell

/// A row of the vault, group and search lists. It is `Equatable` on its state only (the closures always do the same
/// for equal state), so SwiftUI skips its body when the list is re-evaluated for unrelated changes such as a toast,
/// the search text or the bottom bar. Use it through `.equatable()`.
struct VaultListRowCell: View, Equatable {
    /// The state of the row.
    let state: VaultListItemRowState

    /// Performs row effects.
    let perform: (VaultListItemRowEffect) async -> Void

    /// Sends row actions.
    let send: (VaultListItemRowAction) -> Void

    /// The `TimeProvider` used to calculate TOTP expiration.
    let timeProvider: any TimeProvider

    /// Optional delete handler.
    let onDelete: (() -> Void)?

    static func == (lhs: VaultListRowCell, rhs: VaultListRowCell) -> Bool {
        lhs.state == rhs.state
    }

    var body: some View {
        #if DEBUG
        let _ = { PassYPerf.cellBodyCount += 1 }()
        #endif
        VaultListItemRowView(
            state: state,
            perform: perform,
            send: send,
            timeProvider: timeProvider,
            onDelete: onDelete,
        )
    }
}

// MARK: - VaultItemOptionsMenuContent

/// The options of a cipher row as native menu items (SF Symbols), shared by the long-press context menu and the
/// "More" swipe action: the more-options actions, "Move to folder" (`VaultMoveToFolderMenu`), then a divider and the
/// destructive Delete.
struct VaultItemOptionsMenuContent: View {
    /// The applicable more-options actions, in menu order.
    let kinds: [MoreOptionsActionKind]

    /// The row's item for "Move to folder", `nil` for no such entry.
    var item: VaultListItem?

    /// Called with the chosen action.
    let onSelect: (MoreOptionsActionKind) -> Void

    /// Starts the (confirmed) delete of the item, `nil` for no Delete item.
    let onDelete: (() -> Void)?

    var body: some View {
        ForEach(kinds, id: \.localizedName) { kind in
            Button {
                onSelect(kind)
            } label: {
                Label(kind.localizedName, systemImage: kind.passYSymbol)
            }
        }
        VaultMoveToFolderMenu(item: item)
        if let onDelete, !kinds.isEmpty {
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label(Localizations.delete, systemImage: "trash")
            }
        }
    }
}

extension VaultListItem {
    /// The more-options actions of a cipher row; none for groups, codes and ciphers that failed to decrypt.
    func moreOptionsActionKinds(hasPremium: Bool) -> [MoreOptionsActionKind] {
        guard case let .cipher(cipherItem, _) = itemType, !cipherItem.isDecryptionFailure else { return [] }
        return cipherItem.applicableMoreOptionsActionKinds(hasPremium: hasPremium)
    }

    /// The cipher item behind a code row (the more-options helper acts on cipher items), `nil` for other rows.
    var totpCipherItem: VaultListItem? {
        guard case let .totp(_, model) = itemType else { return nil }
        return VaultListItem(cipherListView: model.cipherListView)
    }
}

// MARK: - Swipe actions

extension View {
    /// The trailing swipe actions of a cipher row in the vault, group and search lists (Apple Passwords / Mail
    /// style): icon-only, Delete (red, trash) outermost and More (gray, ellipsis). More is a `Menu` with the items of
    /// the context menu: it drops down from the swipe button instead of presenting a centered sheet. The titles stay
    /// the accessibility labels. Non-cipher rows (groups, codes) have none.
    ///
    /// No `role: .destructive` on Delete (see `passYRowSwipeActions`).
    ///
    /// - Parameters:
    ///   - item: The row's item.
    ///   - hasPremium: Whether the account has Premium (gates Copy TOTP).
    ///   - delete: Starts the (confirmed) delete of the item, `nil` for no Delete action.
    ///   - perform: Performs one of the item's more-options actions.
    ///
    func vaultRowSwipeActions(
        for item: VaultListItem,
        hasPremium: Bool,
        delete: (() -> Void)?,
        perform: @escaping (MoreOptionsActionKind) -> Void,
    ) -> some View {
        passYRowSwipeActions {
            if item.isCipherItem {
                if let delete {
                    Button(action: delete) {
                        Label(Localizations.delete, systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .tint(.red)
                }
                Menu {
                    VaultItemOptionsMenuContent(
                        kinds: item.moreOptionsActionKinds(hasPremium: hasPremium),
                        item: item,
                        onSelect: perform,
                        onDelete: nil,
                    )
                } label: {
                    Label(Localizations.moreOptions, systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                }
                .tint(.gray)
            }
        }
    }
}

// MARK: - MoreOptionsActionKind symbols

extension MoreOptionsActionKind {
    /// The SF Symbol shown next to this action in the options menus.
    var passYSymbol: String {
        switch self {
        case .archive: "archivebox"
        case .unarchive: "tray.and.arrow.up"
        case .edit: "pencil"
        case .launch: "safari"
        case .view: "eye"
        case .copyPassword, .copyPrivateKey: "key"
        case .copyUsername: "person"
        case .copyTotp: "timer"
        default: "doc.on.doc"
        }
    }
}
