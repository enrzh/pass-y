import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SettingsView

/// A view containing the top-level list of settings.
///
struct SettingsView: View {
    // MARK: Properties

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<SettingsState, SettingsAction, SettingsEffect>

    // MARK: View

    var body: some View {
        List {
            settingsItems
        }
        .listStyle(.insetGrouped)
        .navigationBar(title: Localizations.settings, titleDisplayMode: .inline)
        .task {
            await store.perform(.appeared)
        }
        .task {
            await store.perform(.loadProfile)
        }
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearUrl)
        }
        .toolbar {
            closeToolbarItem(hidden: store.state.presentationMode != .preLogin) {
                store.send(.dismiss)
            }

            largeNavigationTitleToolbarItem(
                Localizations.settings,
                hidden: store.state.presentationMode != .tab,
            )
        }
    }

    // MARK: Private views

    /// The settings items.
    @ViewBuilder private var settingsItems: some View {
        if store.state.presentationMode == .preLogin {
            Section {
                row(Localizations.appearance, symbol: "paintbrush", id: "AppearanceSettingsButton") {
                    store.send(.appearancePressed)
                }
                row(Localizations.about, symbol: "info.circle", id: "AboutSettingsButton") {
                    store.send(.aboutPressed)
                }
            }
        } else {
            if let active = store.state.profileState.activeAccountProfile {
                Section { accountRow(active) }
            }
            Section {
                row(
                    Localizations.accountSecurity,
                    symbol: "lock",
                    badge: store.state.accountSecurityBadgeValue,
                    id: "AccountSecuritySettingsButton",
                ) { store.send(.accountSecurityPressed) }
                row(
                    Localizations.autofill,
                    symbol: "checkmark.circle",
                    badge: store.state.autofillBadgeValue,
                    id: "AutofillSettingsButton",
                ) { store.send(.autoFillPressed) }
                row(
                    Localizations.vault,
                    symbol: "key",
                    badge: store.state.vaultBadgeValue,
                    id: "VaultSettingsButton",
                ) { store.send(.vaultPressed) }
                if store.state.showPlanRow {
                    row(Localizations.plan, symbol: "creditcard", id: "PlanSettingsButton") {
                        Task { await store.perform(.planPressed) }
                    }
                }
            }
            Section {
                row(Localizations.appearance, symbol: "paintbrush", id: "AppearanceSettingsButton") {
                    store.send(.appearancePressed)
                }
                row(Localizations.other, symbol: "ellipsis.circle", id: "OtherSettingsButton") {
                    store.send(.otherPressed)
                }
                row(Localizations.about, symbol: "info.circle", id: "AboutSettingsButton") {
                    store.send(.aboutPressed)
                }
            }
        }
    }

    /// The account row at the top (like the Apple ID row): avatar, e-mail, and a menu to switch, lock or log out.
    private func accountRow(_ active: ProfileSwitcherItem) -> some View {
        Menu {
            let others = store.state.profileState.accounts.filter { $0.userId != active.userId }
            ForEach(others, id: \.userId) { account in
                Button(account.email) { store.send(.switchAccountPressed(account)) }
            }
            if active.canBeLocked {
                Button { store.send(.lockPressed) } label: { Label(Localizations.lockNow, systemImage: "lock") }
            }
            Button(role: .destructive) { store.send(.logoutPressed) } label: {
                Label(Localizations.logOut, systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(active.color)
                    Text(active.userInitials ?? "")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(active.profileIconTextColor)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(active.email)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(store.state.profileState.accounts.count > 1 ? Localizations.account : "Pass-Y")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .tint(.primary)
        .accessibilityIdentifier("SettingsAccountRow")
    }

    /// A native settings row: SF Symbol, title, optional badge, disclosure chevron.
    private func row(
        _ title: String,
        symbol: String,
        badge: String? = nil,
        id: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .foregroundStyle(.primary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Tab") {
    NavigationView {
        SettingsView(store: Store(processor: StateProcessor(state: SettingsState())))
    }
}

#Preview("Pre-login") {
    NavigationView {
        SettingsView(store: Store(processor: StateProcessor(state: SettingsState(presentationMode: .preLogin))))
    }
}
#endif
