import BitwardenKit
import BitwardenResources
import Combine
import SwiftUI
import UIKit

// MARK: - Notification.Name

extension Notification.Name {
    /// Asks the bottom search bar to resign first responder immediately.
    static let vaultSearchResign = Notification.Name("de.aiity.passy.vaultSearchResign")
}

// MARK: - PassYDestination

/// The four top-level destinations of the app. They are reachable only from the avatar menu (there is no tab bar).
///
enum PassYDestination: Int, CaseIterable, Identifiable {
    case vault = 0
    case send = 1
    case generator = 2
    case settings = 3

    var id: Int { rawValue }

    /// The accessibility identifier of the avatar menu entry.
    var menuIdentifier: String {
        switch self {
        case .vault: "ProfileMenuVaultButton"
        case .send: "ProfileMenuSendButton"
        case .generator: "ProfileMenuGeneratorButton"
        case .settings: "ProfileMenuSettingsButton"
        }
    }

    /// The SF Symbol of the menu entry.
    var symbol: String {
        switch self {
        case .vault: "lock.shield"
        case .send: "paperplane"
        case .generator: "wand.and.stars"
        case .settings: "gearshape"
        }
    }

    /// The localized title of the menu entry.
    var title: String {
        switch self {
        case .vault: Localizations.myVault
        case .send: Localizations.send
        case .generator: Localizations.generator
        case .settings: Localizations.settings
        }
    }
}

// MARK: - PassYAddEntry

/// One entry of the "+" menu of the persistent bottom bar.
///
struct PassYAddEntry: Identifiable {
    /// A stable identifier.
    let id: String

    /// The action of the entry.
    let action: () -> Void

    /// Whether a divider is shown before this entry.
    var dividerBefore = false

    /// The SF Symbol of the entry.
    let symbol: String

    /// The title of the entry.
    let title: String
}

// MARK: - PassYSearchTarget

/// A screen that consumes the text of the persistent bottom search field.
///
struct PassYSearchTarget {
    /// The "+" menu entries of the screen.
    var entries: [PassYAddEntry]

    /// The stable identity of the screen.
    let id: AnyHashable

    /// Whether the screen is pushed on top of a root screen (the search is cleared when it goes away).
    let isPushed: Bool

    /// Called with the search text.
    let setText: (String) -> Void

    /// Called with `true` while the field is edited or has text.
    let setSearching: (Bool) -> Void
}

// MARK: - PassYProfileMenuSource

/// The data of the avatar menu, published by the vault list (which owns the profile switcher).
///
struct PassYProfileMenuSource {
    let accounts: [ProfileSwitcherItem]
    let activeAccountId: String?
    let activeProfile: ProfileSwitcherItem?
    let addAccount: () -> Void
    let canLock: Bool
    let lock: (ProfileSwitcherItem) -> Void
    let select: (ProfileSwitcherItem) -> Void
    let showsAddAccount: Bool
    let showsPlaceholder: Bool
    let sync: () -> Void
}

// MARK: - PassYShellModel

/// The state shared by the shell (persistent bottom bar, avatar menu) and the screens it hosts.
///
@MainActor
final class PassYShellModel: ObservableObject {
    // MARK: Static

    /// The shared instance.
    static let shared = PassYShellModel()

    // MARK: Properties

    /// The destinations that can be selected (Send can be disabled by policy).
    @Published var availableDestinations: [PassYDestination] = PassYDestination.allCases

    /// The currently shown destination.
    @Published var destination: PassYDestination = .vault

    /// Whether the search field is being edited.
    @Published var isEditing = false

    /// The data of the avatar menu.
    @Published var profileMenu: PassYProfileMenuSource?

    /// The text of the search field.
    @Published var text = ""

    /// The screen that currently consumes the search text.
    @Published private(set) var activeTarget: PassYSearchTarget?

    /// Selects a destination (set by the shell controller).
    var selectDestination: ((PassYDestination) -> Void)?

    // MARK: Private

    private var targets: [PassYSearchTarget] = []

    // MARK: Methods

    /// Whether the search field currently has anything to do.
    var isSearching: Bool { isEditing || !text.isEmpty }

    /// Ends editing and clears the text.
    func cancelSearch() {
        text = ""
        isEditing = false
        NotificationCenter.default.post(name: .vaultSearchResign, object: nil)
    }

    /// Registers (or refreshes) a screen as search consumer. The newest screen wins.
    func register(_ target: PassYSearchTarget) {
        targets.removeAll { $0.id == target.id }
        targets.append(target)
        activeTarget = targets.last
        target.setText(text)
        target.setSearching(isSearching)
    }

    /// Updates the "+" entries of a registered screen without changing its position.
    func updateEntries(id: AnyHashable, entries: [PassYAddEntry]) {
        guard let index = targets.firstIndex(where: { $0.id == id }) else { return }
        targets[index].entries = entries
        activeTarget = targets.last
    }

    /// Unregisters a screen. Leaving a pushed screen clears the search.
    func unregister(id: AnyHashable) {
        guard let removed = targets.first(where: { $0.id == id }) else { return }
        targets.removeAll { $0.id == id }
        activeTarget = targets.last
        if removed.isPushed, !text.isEmpty || isEditing {
            DispatchQueue.main.async { [weak self] in self?.cancelSearch() }
        }
    }

    /// Selects a destination from the avatar menu.
    func select(_ destination: PassYDestination) {
        selectDestination?(destination)
    }
}

// MARK: - Search target modifier

private struct PassYSearchTargetModifier: ViewModifier {
    let entries: [PassYAddEntry]
    let id: AnyHashable
    let isPushed: Bool
    let setText: (String) -> Void
    let setSearching: (Bool) -> Void
    let text: String

    @ObservedObject private var model = PassYShellModel.shared

    private var target: PassYSearchTarget {
        PassYSearchTarget(
            entries: entries,
            id: id,
            isPushed: isPushed,
            setText: setText,
            setSearching: setSearching,
        )
    }

    private var isActive: Bool { model.activeTarget?.id == id }

    func body(content: Content) -> some View {
        content
            .onAppear { model.register(target) }
            .onDisappear { model.unregister(id: id) }
            .onChange(of: model.text) { newValue in
                if isActive { setText(newValue) }
            }
            .onChange(of: model.isSearching) { newValue in
                if isActive { setSearching(newValue) }
            }
            .onChange(of: text) { newValue in
                // The screen cleared or changed its own text (for example a processor reset).
                if isActive, newValue != model.text { model.text = newValue }
            }
            .onChange(of: entries.map { "\($0.id)|\($0.title)" }) { _ in
                model.updateEntries(id: id, entries: entries)
            }
    }
}

extension View {
    /// Makes this screen the consumer of the persistent bottom search field and "+" menu.
    ///
    /// - Parameters:
    ///   - id: The stable identity of the screen.
    ///   - isPushed: Whether the screen is pushed on top of a root screen.
    ///   - text: The screen's current search text.
    ///   - entries: The entries of the "+" menu.
    ///   - setText: Called with the new text of the field.
    ///   - setSearching: Called with whether the field is being edited or has text.
    ///
    func passYSearchTarget(
        id: AnyHashable,
        isPushed: Bool,
        text: String,
        entries: [PassYAddEntry],
        setText: @escaping (String) -> Void,
        setSearching: @escaping (Bool) -> Void,
    ) -> some View {
        modifier(PassYSearchTargetModifier(
            entries: entries,
            id: id,
            isPushed: isPushed,
            setText: setText,
            setSearching: setSearching,
            text: text,
        ))
    }
}

// MARK: - PassYShellBar

/// The persistent bottom bar of the app: one native search field in a single glass capsule and the "+" menu of
/// the current screen (like the search and compose pair in Apple apps). It is hosted by the shell controller, so it
/// stays at the bottom on every screen.
///
struct PassYShellBar: View {
    // MARK: Constants

    /// The height of the soft fade above the bar content.
    static let fadeHeight: CGFloat = 28

    /// The height of the bar content (44 pt controls plus 8 pt above and below).
    static let barHeight: CGFloat = 60

    // MARK: Properties

    @ObservedObject var model: PassYShellModel

    // MARK: View

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                VaultSearchBarRepresentable(isEditing: $model.isEditing, text: $model.text)
                    .frame(height: 44)
                    .modifier(BarBackground(shape: Capsule()))

                if model.isSearching {
                    SearchCancelButton { model.cancelSearch() }
                        .transition(.scale.combined(with: .opacity))
                } else if let entries = model.activeTarget?.entries, !entries.isEmpty {
                    PassYAddMenu(entries: entries)
                        .frame(width: 44, height: 44)
                        .modifier(BarBackground(shape: Circle()))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Self.barHeight)
            .background(Color(.systemGroupedBackground))
        }
        .frame(height: Self.barHeight + Self.fadeHeight)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom,
            )
            .frame(height: Self.fadeHeight)
            .allowsHitTesting(false)
        }
        // Like system toolbars, the floating bar stops growing at the largest non-accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.isSearching)
    }
}

// MARK: - PassYAddMenu

/// The "+" control: a menu for several entries or a plain button for a single one.
private struct PassYAddMenu: View {
    let entries: [PassYAddEntry]

    private var symbol: some View {
        // The whole 44 pt circle is the tap target (the symbol alone is only ~18 pt).
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    var body: some View {
        Group {
            if entries.count == 1, let entry = entries.first {
                Button(action: entry.action) { symbol }
                    .buttonStyle(.plain)
            } else {
                Menu {
                    ForEach(entries) { entry in
                        if entry.dividerBefore { Divider() }
                        Button(action: entry.action) {
                            Label(entry.title, systemImage: entry.symbol)
                        }
                    }
                } label: {
                    symbol
                }
            }
        }
        .accessibilityLabel(Localizations.add)
        .accessibilityIdentifier("AddItemFloatingActionButton")
    }
}

// MARK: - PassYAvatarMenu

/// The single trailing control of every top-level screen: the profile picture (just the avatar, no extra container)
/// that opens a native menu with Vault, Send, Generator and Settings, the accounts, sync and lock.
///
struct PassYAvatarMenu: View {
    @ObservedObject private var model = PassYShellModel.shared

    var body: some View {
        Menu {
            Section {
                ForEach(model.availableDestinations) { destination in
                    Button {
                        model.select(destination)
                    } label: {
                        Label(
                            destination.title,
                            systemImage: destination == model.destination ? "checkmark" : destination.symbol,
                        )
                    }
                    .accessibilityIdentifier(destination.menuIdentifier)
                }
            }

            if let source = model.profileMenu {
                if !source.accounts.isEmpty {
                    Section {
                        ForEach(source.accounts, id: \.userId) { account in
                            Button {
                                source.select(account)
                            } label: {
                                if account.userId == source.activeAccountId {
                                    Label(account.email, systemImage: "checkmark")
                                } else {
                                    Text(account.email)
                                }
                            }
                        }
                        if source.showsAddAccount {
                            Button(action: source.addAccount) {
                                Label(Localizations.addAccount, systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                    }
                }

                Section {
                    Button(action: source.sync) {
                        Label(Localizations.syncNow, systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier("ProfileMenuSyncButton")

                    if source.canLock, let active = source.activeProfile {
                        Button { source.lock(active) } label: {
                            Label(Localizations.lockNow, systemImage: "lock")
                        }
                        .accessibilityIdentifier("ProfileMenuLockButton")
                    }
                }
            }
        } label: {
            avatar
        }
        .accessibilityIdentifier("CurrentActiveAccount")
        .accessibilityLabel(Localizations.account)
    }

    /// The avatar itself: initials on the account color, nothing around it.
    private var avatar: some View {
        let source = model.profileMenu
        let profile = (source?.showsPlaceholder ?? true) ? nil : source?.activeProfile
        return ZStack {
            Circle().fill(profile?.color ?? Color(.tertiarySystemFill))
            if let initials = profile?.userInitials {
                Text(initials)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(profile?.profileIconTextColor ?? .primary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - PassYAvatarToolbarItem

/// The avatar as a toolbar item. On iOS 26 the system toolbar capsule around it is removed, so only the avatar shows.
///
struct PassYAvatarToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) { PassYAvatarMenu() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { PassYAvatarMenu() }
        }
    }
}
