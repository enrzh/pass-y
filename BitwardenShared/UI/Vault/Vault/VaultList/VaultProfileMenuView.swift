import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - VaultProfileMenuView

/// The single toolbar control of the vault screen: a profile icon that opens a native menu with the
/// accounts, add account, sync, lock and settings (modeled after the account button in Apple apps).
///
struct VaultProfileMenuView: View {
    // MARK: Properties

    /// Called when the user chooses to sync the vault.
    let onSync: () async -> Void

    /// Called when the user opens the settings.
    let onSettings: () -> Void

    /// The `Store` of the profile switcher state.
    @ObservedObject var store: Store<ProfileSwitcherState, ProfileSwitcherAction, ProfileSwitcherEffect>

    // MARK: View

    var body: some View {
        Menu {
            if !store.state.accounts.isEmpty {
                Section {
                    ForEach(store.state.accounts, id: \.userId) { account in
                        Button {
                            Task { await store.perform(.accountPressed(account)) }
                        } label: {
                            if account.userId == store.state.activeAccountId {
                                Label(account.email, systemImage: "checkmark")
                            } else {
                                Text(account.email)
                            }
                        }
                    }
                    if store.state.showsAddAccount {
                        Button {
                            Task { await store.perform(.addAccountPressed) }
                        } label: {
                            Label(Localizations.addAccount, systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                }
            }

            Section {
                Button {
                    Task { await onSync() }
                } label: {
                    Label(Localizations.syncNow, systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("ProfileMenuSyncButton")

                if store.state.allowLockAndLogout,
                   let active = store.state.activeAccountProfile,
                   active.canBeLocked {
                    Button {
                        Task { await store.perform(.accessibility(.lock(active))) }
                    } label: {
                        Label(Localizations.lockNow, systemImage: "lock")
                    }
                    .accessibilityIdentifier("ProfileMenuLockButton")
                }

                Button(action: onSettings) {
                    Label(Localizations.settings, systemImage: "gearshape")
                }
                .accessibilityIdentifier("ProfileMenuSettingsButton")
            }
        } label: {
            icon
        }
        .accessibilityIdentifier("CurrentActiveAccount")
        .accessibilityLabel(Localizations.account)
        .hidden(!store.state.showPlaceholderToolbarIcon && store.state.accounts.isEmpty)
    }

    // MARK: Private

    private var icon: some View {
        let profile = store.state.showPlaceholderToolbarIcon ? nil : store.state.activeAccountProfile
        let initials = profile?.userInitials
        return ZStack {
            Circle()
                .fill(profile?.color ?? Color(.tertiarySystemFill))
            if let initials {
                Text(initials)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(profile?.profileIconTextColor ?? .primary)
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
    }
}
