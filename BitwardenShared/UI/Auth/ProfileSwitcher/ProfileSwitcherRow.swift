import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ProfileSwitcherRow

/// A row view that allows the user to view, select, or add profiles.
///
struct ProfileSwitcherRow: View {
    // MARK: Properties

    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceoverEnabled: Bool

    /// The `Store` for this view.
    @ObservedObject var store: Store<ProfileSwitcherRowState, ProfileSwitcherRowAction, ProfileSwitcherRowEffect>

    /// Defines the accessibility focus state
    @AccessibilityFocusState var isFocused: Bool

    var body: some View {
        button
            .onChange(of: store.state.shouldTakeAccessibilityFocus) { shouldTakeFocus in
                updateFocusIfNeeded(shouldTakeFocus: shouldTakeFocus)
            }
            .accessibilityIdentifier("AccountCell")
    }

    // MARK: Private Properties

    /// A button with  accessibility traits for active accounts
    @ViewBuilder private var button: some View {
        switch store.state.rowType {
        case .addAccount:
            AsyncButton {
                await store.perform(.pressed(rowType))
            } label: {
                rowContents
            }
            .accessibilityAsyncAction(named: Localizations.addAccount) {
                await store.perform(.pressed(rowType))
            }
        case let .alternate(account):
            accountRow(for: account, isSelected: false)
        case let .active(account):
            accountRow(for: account, isSelected: true)
        }
    }

    /// The row contents
    private var rowContents: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            HStack(spacing: 0) {
                leadingIcon
                    .padding(.trailing, 16)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                            Text(title)
                                .font(.body)
                                .accessibilityIdentifier("AccountEmailLabel")
                                .foregroundStyle(.primary)
                            if let hostSubtitle {
                                Text(hostSubtitle)
                                    .font(.subheadline)
                                    .accessibilityIdentifier("AccountHostUrlLabel")
                                    .foregroundStyle(.secondary)
                            }
                            if let statusSubtitle {
                                Text(statusSubtitle)
                                    .font(.subheadline)
                                    .accessibilityIdentifier("AccountStatusLabel")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                        .truncationMode(.tail)
                        Spacer()
                        trailingIcon?
                            .font(.title3)
                            .foregroundStyle(trailingIconColor)
                            .accessibilityIdentifier(store.state.trailingIconAccessibilityID)
                    }
                    .padding([.top, .bottom], (statusSubtitle != nil || hostSubtitle != nil) ? 9 : 19)
                    .padding([.trailing], 16)
                    divider
                }
                .padding([.leading], 4)
            }
            .padding([.leading], 16)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    /// A row divider view
    @ViewBuilder private var divider: some View {
        if store.state.showDivider {
            Divider()
        } else {
            EmptyView()
        }
    }

    /// A leading icon for the row
    @ViewBuilder private var leadingIcon: some View {
        switch store.state.rowType {
        case let .active(account),
             let .alternate(account):
            profileSwitcherIcon(
                color: account.color,
                initials: account.userInitials,
                textColor: account.profileIconTextColor,
            )
            .accessibilityLabel(Localizations.account)
        case .addAccount:
            PassYIconTile(systemImage: "plus", tint: .accentColor, size: PassYDesign.IconSize.small)
        }
    }

    /// The type of the row
    private var rowType: ProfileSwitcherRowState.RowType {
        store.state.rowType
    }

    /// A title for the row
    private var title: String {
        switch store.state.rowType {
        case let .active(account),
             let .alternate(account):
            account.email
        case .addAccount:
            Localizations.addAccount
        }
    }

    /// A subtitle for the row, used to indicate vault host
    private var hostSubtitle: String? {
        switch store.state.rowType {
        case let .active(account),
             let .alternate(account):
            account.webVault
        case .addAccount:
            nil
        }
    }

    /// A subtitle for the row, used to indicate lock status
    private var statusSubtitle: String? {
        switch store.state.rowType {
        case .active,
             .addAccount:
            nil
        case let .alternate(account):
            switch (account.isUnlocked, account.isLoggedOut) {
            case (true, false):
                Localizations.accountUnlocked.lowercased()
            case (false, false):
                Localizations.accountLocked.lowercased()
            case (_, true):
                Localizations.accountLoggedOut.lowercased()
            }
        }
    }

    /// A trailing icon for the row
    private var trailingIcon: Image? {
        switch store.state.rowType {
        case .active:
            Image(systemName: "checkmark.circle.fill")
        case let .alternate(account):
            if account.isUnlocked {
                Image(systemName: "lock.open")
            } else {
                Image(systemName: "lock.fill")
            }
        case .addAccount:
            nil
        }
    }

    /// A trailing icon color for the row
    private var trailingIconColor: Color {
        switch store.state.rowType {
        case .active:
            .accentColor
        case .alternate:
            .secondary
        case .addAccount:
            .clear
        }
    }

    /// Builds an account row for a given row type
    ///
    /// - Parameters
    ///     - profileSwitcherItem: The item used to construct the account row.
    ///     - isSelected: Is this item selected?
    ///
    @ViewBuilder
    private func accountRow(
        for profileSwitcherItem: ProfileSwitcherItem,
        isSelected: Bool,
    ) -> some View {
        AsyncButton {} label: {
            rowContents
                .onTapGesture {
                    await store.perform(
                        .pressed(
                            isSelected
                                ? .active(profileSwitcherItem)
                                : .alternate(profileSwitcherItem),
                        ),
                    )
                }
                .onLongPressGesture(if: store.state.allowLockAndLogout) {
                    await store.perform(
                        .longPressed(
                            isSelected
                                ? .active(profileSwitcherItem)
                                : .alternate(profileSwitcherItem),
                        ),
                    )
                }
        }
        .accessibilityAction {
            Task {
                await store.perform(.accessibility(.select(profileSwitcherItem)))
            }
        }
        .conditionalAccessibilityAsyncAction(
            if: store.state.allowLockAndLogout && profileSwitcherItem.canBeLocked
                && profileSwitcherItem.isUnlocked,
            named: Localizations.lock,
        ) {
            await store.perform(.accessibility(.lock(profileSwitcherItem)))
        }
        .conditionalAccessibilityAction(
            if: store.state.allowLockAndLogout && !profileSwitcherItem.isLoggedOut,
            named: Localizations.logOut,
        ) {
            store.send(.accessibility(.logout(profileSwitcherItem)))
        }
        .conditionalAccessibilityAction(
            if: store.state.allowLockAndLogout && profileSwitcherItem.isLoggedOut,
            named: Localizations.remove,
        ) {
            store.send(.accessibility(.remove(profileSwitcherItem)))
        }
        .accessibility(
            if: isSelected,
            addTraits: .isSelected,
        )
    }

    /// Helper function to set accessibility focus state inside the view body
    private func updateFocusIfNeeded(shouldTakeFocus: Bool) {
        if shouldTakeFocus,
           isVoiceoverEnabled {
            isFocused = true
        }
    }
}

#if DEBUG
#Preview("Active Unlocked Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        rowType: .active(.fixtureUnlocked),
                    ),
                ),
            ),
        )
    }
}

#Preview("Active Locked Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        rowType: .active(.fixtureLocked),
                    ),
                ),
            ),
        )
    }
}

#Preview("Active Account, No Divider") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        showDivider: false,
                        rowType: .active(.fixtureLocked),
                    ),
                ),
            ),
        )
    }
}

#Preview("Alternate Unlocked Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        rowType: .alternate(.fixtureUnlocked),
                    ),
                ),
            ),
        )
    }
}

#Preview("Alternate Locked Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        rowType: .alternate(.fixtureLocked),
                    ),
                ),
            ),
        )
    }
}

#Preview("Alternate Logged Out Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: true,
                        rowType: .alternate(.fixtureLoggedOut),
                    ),
                ),
            ),
        )
    }
}

#Preview("Add Account") {
    NavigationView {
        ProfileSwitcherRow(
            store: Store(
                processor: StateProcessor(
                    state: ProfileSwitcherRowState(
                        shouldTakeAccessibilityFocus: false,
                        rowType: .addAccount,
                    ),
                ),
            ),
        )
    }
}
#endif
