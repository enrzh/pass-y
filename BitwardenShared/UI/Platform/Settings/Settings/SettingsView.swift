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

    /// The side of the account avatar, scaled with Dynamic Type (at most 1.6 times).
    @ScaledMetric(relativeTo: .title2) private var avatarSize: CGFloat = 56

    /// The Dynamic Type size (the account row stacks vertically at accessibility sizes).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: View

    var body: some View {
        List {
            settingsItems
        }
        .listStyle(.insetGrouped)
        .navigationBar(
            title: Localizations.settings,
            titleDisplayMode: store.state.presentationMode == .tab ? .large : .inline,
        )
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

            if store.state.presentationMode == .tab {
                PassYAvatarToolbarItem()
            }
        }
    }

    // MARK: Private views

    /// The settings items, in clearly separated sections (iOS Settings style): account, security and data, then
    /// the app itself.
    @ViewBuilder private var settingsItems: some View {
        if store.state.presentationMode == .preLogin {
            Section {
                row(Localizations.appearance, symbol: "paintbrush.fill", tint: .indigo, id: "AppearanceSettingsButton") {
                    store.send(.appearancePressed)
                }
                row(Localizations.about, symbol: "info.circle.fill", tint: .gray, id: "AboutSettingsButton") {
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
                    symbol: "lock.fill",
                    tint: .blue,
                    badge: store.state.accountSecurityBadgeValue,
                    id: "AccountSecuritySettingsButton",
                ) { store.send(.accountSecurityPressed) }
                row(
                    Localizations.autofill,
                    symbol: "key.fill",
                    tint: .green,
                    badge: store.state.autofillBadgeValue,
                    id: "AutofillSettingsButton",
                ) { store.send(.autoFillPressed) }
                row(
                    Localizations.vault,
                    symbol: "archivebox.fill",
                    tint: .orange,
                    badge: store.state.vaultBadgeValue,
                    id: "VaultSettingsButton",
                ) { store.send(.vaultPressed) }
                if store.state.showPlanRow {
                    row(Localizations.plan, symbol: "creditcard.fill", tint: .teal, id: "PlanSettingsButton") {
                        Task { await store.perform(.planPressed) }
                    }
                }
            }
            Section {
                row(Localizations.appearance, symbol: "paintbrush.fill", tint: .indigo, id: "AppearanceSettingsButton") {
                    store.send(.appearancePressed)
                }
                row(Localizations.other, symbol: "gearshape.fill", tint: .gray, id: "OtherSettingsButton") {
                    store.send(.otherPressed)
                }
            }
            Section {
                row(Localizations.about, symbol: "info.circle.fill", tint: .gray, id: "AboutSettingsButton") {
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
            Button { store.send(.addAccountPressed) } label: {
                Label(Localizations.addAccount, systemImage: "person.crop.circle.badge.plus")
            }
            .accessibilityIdentifier("SettingsAddAccountButton")
            if active.canBeLocked {
                Button { store.send(.lockPressed) } label: { Label(Localizations.lockNow, systemImage: "lock") }
            }
            Button(role: .destructive) { store.send(.logoutPressed) } label: {
                Label(Localizations.logOut, systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            // At accessibility sizes the avatar sits above the text (no squeezed, centred column).
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: PassYDesign.Spacing.small))
                : AnyLayout(HStackLayout(spacing: 14))
            layout {
                ZStack {
                    Circle().fill(active.color)
                    Text(active.userInitials ?? "")
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .foregroundStyle(active.profileIconTextColor)
                }
                .frame(
                    width: min(avatarSize, PassYDesign.IconSize.large * 1.6),
                    height: min(avatarSize, PassYDesign.IconSize.large * 1.6),
                )
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(active.email)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                            .truncationMode(.middle)
                        Text(store.state.serverURL)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .tint(.primary)
        .accessibilityIdentifier("SettingsAccountRow")
    }

    /// A settings row: tinted SF Symbol tile, title, optional badge, disclosure chevron (`PassYSettingsRow`).
    private func row(
        _ title: String,
        symbol: String,
        tint: Color = .accentColor,
        badge: String? = nil,
        id: String,
        action: @escaping () -> Void,
    ) -> some View {
        PassYSettingsRow(title, systemImage: symbol, tint: tint, badge: badge, identifier: id, action: action)
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
