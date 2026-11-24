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

/// The four top-level destinations of the app. Send, Generator and Settings are reachable from the avatar menu; the
/// vault is reached with the Vault button of the bottom bar (there is no tab bar).
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
    let activeProfile: ProfileSwitcherItem?
    let canLock: Bool
    let lock: (ProfileSwitcherItem) -> Void
    let pendingRequests: () -> Void
    /// The connected server (shown at the top of the menu).
    let serverURL: String
    let showsPlaceholder: Bool
    let sync: () -> Void
}

extension URL {
    /// The URL as shown to the user: the absolute string without a trailing slash.
    var passYServerText: String {
        let text = absoluteString
        return text.hasSuffix("/") ? String(text.dropLast()) : text
    }
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

    /// Whether the vault home (the root of the vault stack) is shown. The Vault button of the bar is hidden then.
    @Published var isAtVaultHome = true

    /// The data of the avatar menu.
    @Published var profileMenu: PassYProfileMenuSource?

    /// The text of the search field.
    @Published var text = ""

    /// The screen that currently consumes the search text.
    @Published private(set) var activeTarget: PassYSearchTarget?

    /// Selects a destination (set by the shell controller).
    var selectDestination: ((PassYDestination) -> Void)?

    /// Shows the vault home: switches to the vault, pops to its root and clears the search (set by the shell
    /// controller).
    var goToVault: (() -> Void)?

    /// The frames of the bar controls in the bar's coordinate space. Everything else in the bar passes touches
    /// through to the page below.
    var controlFrames: [CGRect] = []

    // MARK: Private

    private var targets: [PassYSearchTarget] = []

    // MARK: Methods

    /// Whether the search field currently has anything to do.
    var isSearching: Bool { isEditing || !text.isEmpty }

    /// Ends editing and clears the text.
    func cancelSearch() {
        #if DEBUG
        PassYPerf.mark("bar.cancelSearch")
        #endif
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
            // `task(id:)` instead of `onChange`: its closure is created with the newest `entries`
            // (an `onChange` action would still see the previous ones).
            .task(id: entries.map { "\($0.id)|\($0.title)" }) {
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

    /// Nothing is drawn above the bar content any more (ui-r8: no fade or shadow behind the bar).
    static let fadeHeight: CGFloat = 0

    /// The height of the bar content (44 pt controls plus 8 pt above and below).
    static let barHeight: CGFloat = 60

    /// The coordinate space the control frames are measured in.
    static let coordinateSpace = "PassYBar"

    // MARK: Properties

    @ObservedObject var model: PassYShellModel

    // MARK: View

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                if !model.isAtVaultHome {
                    PassYVaultButton { model.goToVault?() }
                        .reportsBarFrame()
                        .transition(.scale.combined(with: .opacity))
                }

                VaultSearchBarRepresentable(isEditing: $model.isEditing, text: $model.text)
                    .frame(height: 44)
                    .modifier(BarBackground(shape: Capsule()))
                    .reportsBarFrame()

                if model.isSearching {
                    SearchCancelButton { model.cancelSearch() }
                        .reportsBarFrame()
                        .transition(.scale.combined(with: .opacity))
                } else if let entries = model.activeTarget?.entries, !entries.isEmpty {
                    PassYAddMenu(entries: entries)
                        .frame(width: 44, height: 44)
                        .background { PassYGlassBackground(shape: Circle()) }
                        .reportsBarFrame()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: Self.barHeight)
        }
        .frame(height: Self.barHeight + Self.fadeHeight)
        .coordinateSpace(name: Self.coordinateSpace)
        .onPreferenceChange(PassYBarFramesKey.self) { model.controlFrames = $0 }
        // Like system toolbars, the floating bar stops growing at the largest non-accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.isSearching)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.isAtVaultHome)
    }
}

// MARK: - PassYBarFramesKey

/// Collects the frames of the bar controls.
struct PassYBarFramesKey: PreferenceKey {
    static let defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value += nextValue()
    }
}

extension View {
    /// Reports this control's frame (in the bar's coordinate space) so the rest of the bar can pass touches through.
    func reportsBarFrame() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PassYBarFramesKey.self,
                    value: [proxy.frame(in: .named(PassYShellBar.coordinateSpace))],
                )
            },
        )
    }
}

// MARK: - PassYVaultButton

/// The Vault button left of the search field: returns to the vault home from every other page.
struct PassYVaultButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "lock.shield")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(BarBackground(shape: Circle()))
        .accessibilityLabel(Localizations.myVault)
        .accessibilityIdentifier("BottomBarVaultButton")
    }
}

// MARK: - PassYAddMenu

/// The "+" control: a menu for several entries or a plain button for a single one.
private struct PassYAddMenu: View {
    let entries: [PassYAddEntry]

    private var symbol: some View {
        // The whole 44 pt circle is the tap target (the symbol alone is only ~18 pt).
        Image(systemName: "plus")
            .font(.body.weight(.semibold))
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    var body: some View {
        // A lone folder entry (item types not loaded yet) still opens a menu; only a real single action is a plain button.
        if entries.count == 1, let entry = entries.first, !entry.dividerBefore {
            Button(action: entry.action) { symbol }
                .buttonStyle(.plain)
                .accessibilityLabel(Localizations.add)
                .accessibilityIdentifier("AddItemFloatingActionButton")
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
            .accessibilityLabel(Localizations.add)
            .accessibilityIdentifier("AddItemFloatingActionButton")
        }
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
            if let source = model.profileMenu, !source.serverURL.isEmpty {
                // The connected server, like the account line of Apple's own menus (not an action).
                Section(source.serverURL) {
                    destinationButtons
                }
            } else {
                Section { destinationButtons }
            }
            if let source = model.profileMenu {
                Section {
                    Button(action: source.pendingRequests) {
                        Label(Localizations.pendingLogInRequests, systemImage: "person.badge.clock")
                    }
                    .accessibilityIdentifier("ProfileMenuPendingRequestsButton")
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

    /// Send, Generator and Settings (the vault is the Vault button of the bar).
    @ViewBuilder private var destinationButtons: some View {
        ForEach(model.availableDestinations.filter { $0 != .vault }) { destination in
            Button {
                model.select(destination)
            } label: {
                Label(destination.title, systemImage: destination == model.destination ? "checkmark" : destination.symbol)
            }
            .accessibilityIdentifier(destination.menuIdentifier)
        }
    }

    /// The avatar itself: initials on the account color, nothing around it.
    private var avatar: some View {
        let source = model.profileMenu
        let profile = (source?.showsPlaceholder ?? true) ? nil : source?.activeProfile
        return ZStack {
            Circle().fill(profile?.color ?? Color(.tertiarySystemFill))
            if profile?.userInitials != nil {
                // ui-r7: darkened just enough that the white initials reach a 4.6:1 contrast on any account color.
                Circle().fill(Color.black.opacity(Self.darkening(for: profile?.color)))
            }
            if let initials = profile?.userInitials {
                Text(initials)
                    .font(Font.system(.body, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.avatarSize, height: Self.avatarSize)
    }

    /// The opacity of a black overlay (0 to 0.6) after which white text on `color` has a contrast ratio of at least 4.6.
    static func darkening(for color: Color?) -> Double {
        guard let color else { return 0.3 }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0.3 }
        func linear(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        for step in 0 ... 12 {
            let factor = 1 - Double(step) * 0.05
            let luminance = 0.2126 * linear(red * factor) + 0.7152 * linear(green * factor) + 0.0722 * linear(blue * factor)
            if 1.05 / (luminance + 0.05) >= 4.6 { return Double(step) * 0.05 }
        }
        return 0.6
    }

    /// The avatar diameter: the 44 pt of the neighbouring glass toolbar buttons (back, Select, "..."), so it has the
    /// same size and weight. Fixed like those buttons: a Dynamic Type size would outgrow the bar; the initials shrink
    /// to fit instead.
    static let avatarSize: CGFloat = 44
}

// MARK: - PassYAvatarToolbarItem

/// The avatar as a toolbar item, without the system toolbar capsule around it, so only the avatar shows.
///
struct PassYAvatarToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) { PassYAvatarMenu() }
            .sharedBackgroundVisibility(.hidden)
    }
}
