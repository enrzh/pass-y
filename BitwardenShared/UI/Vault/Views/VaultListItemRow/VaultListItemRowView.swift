import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - View+MoreOptionsAccessibilityActions

private extension ModifiedContent where Modifier == AccessibilityAttachmentModifier {
    /// Adds a named `.accessibilityAction` for each of the provided more-options action kinds.
    /// The number of kinds is data-driven (it depends on the cipher's `copyableFields`), so this
    /// folds over the list at runtime. Accessibility actions applied to
    /// `AccessibilityAttachmentModifier` content merge into the same modifier, so the view's type
    /// stays the same however many kinds are added.
    ///
    /// - Parameters:
    ///   - kinds: The more-options action kinds to expose as accessibility actions.
    ///   - onSelect: Called with the selected kind when its accessibility action is activated.
    ///
    func accessibilityMoreOptionsActions(
        _ kinds: [MoreOptionsActionKind],
        onSelect: @escaping (MoreOptionsActionKind) async -> Void,
    ) -> ModifiedContent<Content, Modifier> {
        kinds.reduce(self) { view, kind in
            view.accessibilityAction(named: kind.localizedName) {
                Task { await onSelect(kind) }
            }
        }
    }
}

// MARK: - VaultListItemRowView

/// A view that displays information about a `VaultListItem` as a row in a list.
struct VaultListItemRowView: View {
    // MARK: Properties

    /// Where the row reads its state from and sends actions and effects to. Either a `Store` (extension lists,
    /// previews, tests) or plain values and closures (the vault lists: no child `Store` per row and per body pass).
    let store: Source

    /// The `TimeProvider` used to calculate TOTP expiration.
    var timeProvider: (any TimeProvider)?

    /// Optional delete handler; when set the context menu offers "Delete".
    var onDelete: (() -> Void)?

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

    var body: some View {
        let _ = { PassYPerf.rowBodyCount += 1 }()
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                AsyncButton {
                    PassYPerf.beginTap()
                    await store.perform(.pressed)
                } label: {
                    HStack(spacing: 16) {
                        VaultItemDecorativeImageView(
                            item: store.state.item,
                            iconBaseURL: store.state.iconBaseURL,
                            showWebIcons: store.state.showWebIcons,
                        ) { _ in
                            Group {
                                if case let .cipher(cipherItem, _) = store.state.item.itemType {
                                    ItemLetterIcon(name: cipherItem.name)
                                }
                            }
                        }
                        .imageStyle(.rowIcon)
                        // Apple Passwords: the icon sits in a 40 pt rounded square with a hairline border.
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color(.separator), lineWidth: 0.5))
                        .padding(.vertical, 8)

                        HStack {
                            switch store.state.item.itemType {
                            case let .cipher(cipherItem, _):
                                cipherRowLabel(cipherItem)
                            case let .group(group, count):
                                groupRowLabel(group, count)
                            case let .totp(name, model):
                                totpRowLabel(name, model)
                            }
                        }
                        .padding(.vertical, 9)

                        Spacer(minLength: 0)

                        if showsChevron {
                            // Apple Passwords: a disclosure chevron instead of a "..." button. The options (copy,
                            // edit, delete ...) live in the long-press context menu and the swipe actions.
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                                .accessibilityHidden(true)
                                .accessibilityIdentifier("CipherDisclosureChevron")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // ui-r8: with `.plain` only drawn content is tappable. The blank space between text and chevron
                    // and the chevron itself are part of the hit area (one tap opens the item). The 16 pt side
                    // margin stays outside the button on purpose: a button as wide as the row is merged by the
                    // accessibility system with the row container, the row identifier (`CipherCell`, `FolderCell`)
                    // then replaced `VaultListItemRowButton` (found in the UI test tree dump).
                    .contentShape(Rectangle())
                }
                // In a `List`, several default-style buttons in one row would all fire on a single tap.
                .buttonStyle(.plain)
                .accessibilityIdentifier("VaultListItemRowButton")
                .allowsHitTesting(!store.state.isSelecting)
                .hoverEffect(.highlight)

                if case let .totp(_, model) = store.state.item.itemType,
                   !model.requiresMasterPassword, store.state.showTotpCopyButton {
                    Button {
                        store.send(.copyTOTPCode(model.totpCode.code))
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .hoverEffect(.highlight)
                    .accessibilityLabel(Localizations.copyTotp)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)

            if store.state.hasDivider {
                Divider()
                    .padding(.leading, 40 + 16 + 16)
            }
        }
        .onAppear { PassYPerf.rowAppeared(store.state.item.id) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(store.state.item.vaultItemAccessibilityId)
        .accessibilityMoreOptionsActions(accessibilityMoreOptionsActionKinds) { kind in
            await store.perform(.accessibilityMoreOptionsActionPressed(kind))
        }
        .contextMenu {
            ForEach(accessibilityMoreOptionsActionKinds, id: \.localizedName) { kind in
                Button {
                    Task { await store.perform(.accessibilityMoreOptionsActionPressed(kind)) }
                } label: {
                    Label(kind.localizedName, systemImage: kind.passYSymbol)
                }
            }
            if let onDelete, !accessibilityMoreOptionsActionKinds.isEmpty {
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(Localizations.delete, systemImage: "trash")
                }
            }
        }
    }

    /// Whether the disclosure chevron is shown (cipher rows that open an item).
    private var showsChevron: Bool {
        guard case let .cipher(cipherItem, _) = store.state.item.itemType else { return false }
        return !store.state.isFromExtension && !cipherItem.isDecryptionFailure
    }

    /// The more-options accessibility action kinds applicable to this row, empty for non-cipher
    /// items, decryption-failure ciphers, or when running in an extension (matching the ellipsis
    /// button's own visibility gate).
    private var accessibilityMoreOptionsActionKinds: [MoreOptionsActionKind] {
        guard case let .cipher(cipherItem, _) = store.state.item.itemType,
              !store.state.isFromExtension, !cipherItem.isDecryptionFailure else {
            return []
        }
        return cipherItem.applicableMoreOptionsActionKinds(hasPremium: store.state.hasPremium)
    }

    // MARK: - Private Views

    /// The label content for a cipher row, excluding the more-options button.
    @ViewBuilder
    private func cipherRowLabel(_ cipherItem: CipherListView) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(cipherItem.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
                    .lineLimit(1)
                    .accessibilityIdentifier("CipherNameLabel")

                if cipherItem.organizationId != nil {
                    SharedAsset.Icons.sharedFolder16.swiftUIImage
                        .imageStyle(.accessoryIcon16(
                            color: SharedAsset.Colors.textSecondary.swiftUIColor,
                            scaleWithFont: true,
                        ))
                        .accessibilityLabel(Localizations.shared)
                        .accessibilityIdentifier("CipherInCollectionIcon")
                }

                if cipherItem.attachments > 0 {
                    SharedAsset.Icons.paperclip16.swiftUIImage
                        .imageStyle(.accessoryIcon16(
                            color: SharedAsset.Colors.textSecondary.swiftUIColor,
                            scaleWithFont: true,
                        ))
                        .accessibilityLabel(Localizations.attachments)
                        .accessibilityIdentifier("CipherWithAttachmentsIcon")
                }
            }

            if store.state.item.shouldShowFido2CredentialRpId,
               let fido2CredentialRpId = store.state.item.fido2CredentialRpId {
                Text(fido2CredentialRpId)
                    .styleGuide(.subheadline)
                    .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
                    .lineLimit(1)
                    .accessibilityIdentifier("CipherFido2CredentialRpIdLabel")
            }

            if let subTitle = store.state.item.subtitle, !subTitle.isEmpty {
                Text(subTitle)
                    .styleGuide(.subheadline)
                    .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
                    .lineLimit(1)
                    .accessibilityIdentifier("CipherSubTitleLabel")
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The label content for a group row.
    @ViewBuilder
    private func groupRowLabel(_ group: VaultListGroup, _ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.name)
                .styleGuide(.body)
                .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
                .accessibilityIdentifier("GroupNameLabel")

            if let subTitle = store.state.item.subtitle, !subTitle.isEmpty {
                Text(subTitle)
                    .styleGuide(.subheadline)
                    .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
                    .lineLimit(1)
                    .accessibilityIdentifier("GroupSubTitleLabel")
            }
        }
        .accessibilityElement(children: .combine)

        Spacer()

        if let accessoryIcon = store.state.item.accessoryIcon {
            Image(decorative: accessoryIcon)
                .imageStyle(.rowIcon)
                .accessibilityHidden(true)
        } else {
            Text("\(count)")
                .styleGuide(.body)
                .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
                .accessibilityIdentifier("GroupCountLabel")
        }
    }

    /// The label content for a row showing the totp code, excluding the copy button.
    @ViewBuilder
    private func totpRowLabel(
        _ name: String,
        _ model: VaultListTOTP,
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name)
                .styleGuide(.body)
                .lineLimit(1)
                .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
            if let username = model.cipherListView.type.loginListView?.username {
                Text(username)
                    .styleGuide(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(SharedAsset.Colors.textSecondary.swiftUIColor)
            }
        }
        Spacer()
        if let timeProvider {
            TOTPCountdownTimerView(
                timeProvider: timeProvider,
                totpCode: model.totpCode,
                onExpiration: nil,
            )
        }
        if !model.requiresMasterPassword {
            Text(model.totpCode.displayCode)
                .styleGuide(.body, monoSpacedDigit: true)
                .foregroundColor(SharedAsset.Colors.textPrimary.swiftUIColor)
        }
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
        let _ = { PassYPerf.cellBodyCount += 1 }()
        VaultListItemRowView(
            state: state,
            perform: perform,
            send: send,
            timeProvider: timeProvider,
            onDelete: onDelete,
        )
    }
}

// MARK: - MoreOptionsActionKind symbols

extension MoreOptionsActionKind {
    /// The SF Symbol shown next to this action in the context menu.
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
