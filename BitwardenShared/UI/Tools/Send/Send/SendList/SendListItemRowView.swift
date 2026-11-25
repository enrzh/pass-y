import BitwardenKit
import BitwardenResources
@preconcurrency import BitwardenSdk
import SwiftUI

// MARK: - SendListItemRowState

/// An object representing the visual state of a `SendListItemRowState`.
struct SendListItemRowState: Equatable {
    // MARK: Properties

    /// The accessibility identifier for the `SendListItem`.
    var accessibilityIdentifier: String {
        switch item.itemType {
        case .send:
            "SendCell"
        case let .group(type, _):
            switch type {
            case .text:
                "SendTextFilter"
            case .file:
                "SendFileFilter"
            case .unknown:
                ""
            }
        }
    }

    /// Whether sends are disabled via a policy.
    var isSendDisabled = false

    /// The item displayed in this row.
    var item: SendListItem

    /// A flag indicating if this row should display a divider on the bottom edge.
    var hasDivider: Bool
}

// MARK: - SendListItemRowAction

/// Actions that can be sent from a `SendListItemRowView`.
enum SendListItemRowAction: Equatable, Sendable {
    /// The edit button was pressed.
    case editPressed(_ sendView: SendView)

    /// The item was pressed.
    case sendListItemPressed(SendListItem)

    /// The view send button was tapped.
    case viewSend(_ sendView: SendView)
}

// MARK: - SendListItemRowEffect

enum SendListItemRowEffect: Equatable, Sendable {
    /// The copy link button was pressed.
    case copyLinkPressed(_ sendView: SendView)

    /// The delete button was pressed.
    case deletePressed(_ sendView: SendView)

    /// The remove password button was pressed.
    case removePassword(_ sendView: SendView)

    /// The share link button was pressed.
    case shareLinkPressed(_ sendView: SendView)
}

// MARK: - SendListItemView

/// A row of the Send list: a `PassYRow` with the type tile, the name, the deletion date and quiet status badges
/// (disabled, password, access limit, expired, pending deletion), and the row's "..." options menu; group rows (Text,
/// File) show their count and a chevron. Identifiers kept for the UI tests: `SendCell` (`SendTextFilter`,
/// `SendFileFilter`), `SendNameLabel`, `SendDateLabel`, `SendOptionsButton` and the status icon identifiers.
struct SendListItemRowView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<SendListItemRowState, SendListItemRowAction, SendListItemRowEffect>

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            row(for: store.state.item)
                .passYRowButton(horizontalBleed: PassYDesign.Spacing.large) {
                    store.send(.sendListItemPressed(store.state.item))
                }

            if case let .send(sendView) = store.state.item.itemType {
                optionsMenu(for: sendView)
                    .accessibilityLabel(Localizations.moreOptions)
            }
        }
        .padding(.horizontal, PassYDesign.Spacing.large)
        .overlay(alignment: .bottom) {
            if store.state.hasDivider {
                Divider()
                    .padding(.leading, PassYDesign.Spacing.large + PassYDesign.IconSize.row + PassYDesign.Spacing.medium)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(store.state.accessibilityIdentifier)
    }

    // MARK: Private Views

    /// The row content for the item.
    @ViewBuilder
    private func row(for item: SendListItem) -> some View {
        switch item.itemType {
        case let .send(sendView):
            PassYRow(
                title: .init(text: sendView.name, identifier: "SendNameLabel"),
                subtitles: [.init(text: sendView.deletionDate.dateTimeDisplay, identifier: "SendDateLabel")],
            ) {
                PassYIconTile(
                    systemImage: sendView.type == .file ? SendType.file.passYSymbol : SendType.text.passYSymbol,
                    tint: sendView.disabled ? .gray : .blue,
                )
            } titleAccessory: {
                ForEach(statusBadges(for: sendView), id: \.identifier) { badge in
                    PassYBadge(
                        systemImage: badge.symbol,
                        tint: badge.tint,
                        label: badge.label,
                        identifier: badge.identifier,
                    )
                }
            }
        case let .group(sendType, count):
            PassYRow(title: .init(text: sendType.localizedName), showsDisclosure: true) {
                PassYIconTile(systemImage: sendType.passYSymbol, tint: .blue)
            } trailing: {
                Text("\(count)")
                    .passYFont(.rowValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// An options menu to display for a send.
    ///
    /// - Parameter sendView: The `SendView` to display a menu for.
    ///
    @ViewBuilder
    private func optionsMenu(for sendView: SendView) -> some View {
        // A native pull-down menu from the row's "..." (SF Symbols; the destructive Delete last, after a divider).
        Menu {
            if !store.state.isSendDisabled {
                if !sendView.disabled {
                    AsyncButton {
                        await store.perform(.copyLinkPressed(sendView))
                    } label: {
                        Label(Localizations.copyLink, systemImage: "link")
                    }
                    .accessibilityIdentifier("Copy")
                    AsyncButton {
                        await store.perform(.shareLinkPressed(sendView))
                    } label: {
                        Label(Localizations.shareLink, systemImage: "square.and.arrow.up")
                    }
                    Divider()
                }

                Button {
                    store.send(.viewSend(sendView))
                } label: {
                    Label(Localizations.view, systemImage: "eye")
                }
                if !sendView.disabled {
                    Button {
                        store.send(.editPressed(sendView))
                    } label: {
                        Label(Localizations.edit, systemImage: "pencil")
                    }
                    if sendView.hasPassword {
                        AsyncButton {
                            await store.perform(.removePassword(sendView))
                        } label: {
                            Label(Localizations.removePassword, systemImage: "lock.open")
                        }
                    }
                }
                Divider()
            }
            AsyncButton(role: .destructive) {
                await store.perform(.deletePressed(sendView))
            } label: {
                Label(Localizations.delete, systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("SendOptionsButton")
    }

    /// The quiet status badges of a send, in a fixed order.
    private func statusBadges(for sendView: SendView) -> [SendStatusBadge] {
        var badges: [SendStatusBadge] = []
        if sendView.disabled {
            badges.append(.init(
                identifier: "DisabledSendIcon",
                symbol: "exclamationmark.triangle.fill",
                tint: .orange,
                label: "Deactivated",
            ))
        }
        if sendView.hasPassword {
            badges.append(.init(identifier: "PasswordProtectedSendIcon", symbol: "key.fill", label: Localizations.password))
        }
        if let maxAccessCount = sendView.maxAccessCount, sendView.accessCount >= maxAccessCount {
            badges.append(.init(
                identifier: "MaxAccessSendIcon",
                symbol: "nosign",
                label: Localizations.maximumAccessCount,
            ))
        }
        if let expirationDate = sendView.expirationDate, expirationDate < Date() {
            badges.append(.init(identifier: "ExpiredSendIcon", symbol: "clock.badge.xmark", label: Localizations.expired))
        }
        if sendView.deletionDate < Date() {
            badges.append(.init(
                identifier: "PendingDeletionSendIcon",
                symbol: "trash",
                label: "Pending deletion",
            ))
        }
        return badges
    }
}

// MARK: - SendStatusBadge

/// A status badge of a send row.
private struct SendStatusBadge {
    /// The accessibility identifier (kept for the UI tests).
    let identifier: String

    /// The SF Symbol.
    let symbol: String

    /// The colour, `nil` for the quiet secondary colour.
    var tint: Color?

    /// The spoken label.
    let label: String
}

// MARK: - SendType + symbol

extension SendType {
    /// The SF Symbol of the type tile.
    var passYSymbol: String {
        switch self {
        case .file: "doc.fill"
        case .text, .unknown: "text.alignleft"
        }
    }
}

// MARK: - SendListItemIcon

/// An icon used in the `SendListItemRowView`.
///
struct SendListItemIcon: Hashable {
    /// The icon's accessibility ID.
    let accessibilityID: String

    /// The asset for the icon.
    let asset: Image

    func hash(into hasher: inout Hasher) {
        hasher.combine(accessibilityID)
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    VStack {
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(id: "1", itemType: .group(.text, 42)),
                        hasDivider: true,
                    ),
                ),
            ),
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(id: "1", itemType: .group(.file, 42)),
                        hasDivider: true,
                    ),
                ),
            ),
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(
                            id: "3",
                            itemType: .send(.fixture(
                                id: "3",
                                name: "All Statuses",
                                hasPassword: true,
                                type: .text,
                                maxAccessCount: 1,
                                accessCount: 1,
                                disabled: true,
                                deletionDate: Date(),
                                expirationDate: Date().advanced(by: -1),
                            )),
                        ),
                        hasDivider: true,
                    ),
                ),
            ),
        )
        SendListItemRowView(
            store: Store(
                processor: StateProcessor(
                    state: SendListItemRowState(
                        item: SendListItem(
                            id: "4",
                            itemType: .send(.fixture(
                                id: "4",
                                name: "No Status",
                                deletionDate: Date().advanced(by: 100),
                                expirationDate: Date().advanced(by: 100),
                            )),
                        ),
                        hasDivider: false,
                    ),
                ),
            ),
        )
    }
}
#endif
