import BitwardenKit
import Foundation
import SwiftUI

// MARK: - PassYLayoutStore

/// The live layout preferences of the device (`PassYLayoutPreferences`), observable in three independent slices
/// (home, rows, codes): a view that reads only the code options is not invalidated by a row option and vice versa.
/// Every change is written to the app settings right away.
///
/// Pages are separate hosting controllers (there is no single SwiftUI root), so every list page applies the
/// preferences with `passYLayoutEnvironment()`; rows then read only the small value they need from the environment
/// (`passYRowOptions`, `passYTileColors`, `passYCodeOptions`, `passYHomeLayout`).
///
@MainActor
@Observable
final class PassYLayoutStore {
    // MARK: Static

    /// The store of the app (the app group settings, like the rest of the app settings).
    static let shared: PassYLayoutStore = {
        let store = PassYLayoutStore(
            appSettingsStore: DefaultAppSettingsStore(
                userDefaults: UserDefaults(suiteName: Bundle.main.groupIdentifier) ?? .standard,
            ),
        )
        #if DEBUG
        store.applyLaunchPreset(ProcessInfo.processInfo.arguments)
        #endif
        return store
    }()

    // MARK: Properties

    /// The vault home slice.
    var home: PassYLayoutPreferences.Home {
        didSet { if home != oldValue { save() } }
    }

    /// The list row slice.
    var rows: PassYLayoutPreferences.Rows {
        didSet { if rows != oldValue { save() } }
    }

    /// The verification code slice.
    var codes: PassYLayoutPreferences.Codes {
        didSet { if codes != oldValue { save() } }
    }

    /// Where the preferences are stored.
    @ObservationIgnored private let appSettingsStore: (any AppSettingsStore)?

    // MARK: Initialization

    /// Creates a store that loads from and saves to `appSettingsStore` (`nil`: in memory only, for previews).
    ///
    /// - Parameters:
    ///   - appSettingsStore: Where the preferences are stored.
    ///   - initial: The preferences when nothing is stored yet.
    ///
    init(appSettingsStore: (any AppSettingsStore)?, initial: PassYLayoutPreferences = .default) {
        self.appSettingsStore = appSettingsStore
        let stored = appSettingsStore?.passYLayoutPreferences ?? initial
        home = stored.home
        rows = stored.rows
        codes = stored.codes
    }

    // MARK: Methods

    /// All preferences at once.
    var preferences: PassYLayoutPreferences {
        get { PassYLayoutPreferences(home: home, rows: rows, codes: codes) }
        set {
            home = newValue.home
            rows = newValue.rows
            codes = newValue.codes
        }
    }

    /// Whether everything is at its default.
    var isDefault: Bool { preferences == .default }

    /// Restores the defaults (today's look).
    func reset() {
        preferences = .default
    }

    /// Writes the current preferences.
    private func save() {
        appSettingsStore?.passYLayoutPreferences = preferences
    }

    #if DEBUG
    /// UI tests and screenshots: `-PassYLayoutPreset <name>` sets a known configuration at launch (`default`,
    /// `wide`, `list`, `minimal`).
    func applyLaunchPreset(_ arguments: [String]) {
        guard let index = arguments.firstIndex(of: "-PassYLayoutPreset"), arguments.indices.contains(index + 1),
              let preset = PassYLayoutPreferences.preset(named: arguments[index + 1]) else { return }
        preferences = preset
    }
    #endif
}

#if DEBUG
extension PassYLayoutPreferences {
    /// The named configurations of the screenshot runs.
    static func preset(named name: String) -> PassYLayoutPreferences? {
        var preferences = PassYLayoutPreferences.default
        switch name {
        case "default":
            break
        case "wide":
            preferences.home.tileLayout = .wide
            preferences.home.hiddenTiles = ["archive", "trash"]
            preferences.rows.tileColors = .monochrome
        case "list":
            preferences.home.tileLayout = .list
            preferences.home.tileOrder = ["login", "totp", "card", "identity", "secureNote", "sshKey"]
            preferences.rows.density = .compact
        case "minimal":
            preferences.home.hiddenTiles = ["card", "identity", "driversLicense", "passport", "sshKey", "bankAccount"]
            preferences.home.hiddenSections = ["Favorites"]
            preferences.rows.showsSubtitle = false
            preferences.rows.showsIcon = false
        default:
            return nil
        }
        return preferences
    }
}
#endif

// MARK: - Environment

/// The row options of a list page (`PassYRow`, `PassYCodeRow`).
struct PassYRowOptions: Equatable, Sendable {
    /// The row density.
    var density: PassYLayoutPreferences.Density = .comfortable

    /// Whether subtitles are shown.
    var showsSubtitle = true

    /// Whether the leading icon tile is shown.
    var showsIcon = true

    /// The minimum height of a row.
    var minHeight: CGFloat {
        density == .compact ? 44 : PassYDesign.Row.minHeight
    }

    /// The vertical padding of a row's content.
    var verticalPadding: CGFloat {
        density == .compact ? PassYDesign.Spacing.xSmall : PassYDesign.Row.verticalPadding
    }
}

/// The badges a vault row shows.
struct PassYBadgeOptions: Equatable, Sendable {
    var favorite = true
    var shared = true
    var attachments = true
}

/// How verification codes are drawn (`PassYCodeRow`, `PassYCountdownRing`).
struct PassYCodeOptions: Equatable, Sendable {
    var groupsDigits = true
    var showsRing = true
    var showsSeconds = true
}

extension EnvironmentValues {
    /// The row options of the page (default: today's rows).
    @Entry var passYRowOptions = PassYRowOptions()

    /// The badge options of the page.
    @Entry var passYBadgeOptions = PassYBadgeOptions()

    /// The icon tile colours of the page.
    @Entry var passYTileColors: PassYLayoutPreferences.TileColors = .colorful

    /// The code options of the page.
    @Entry var passYCodeOptions = PassYCodeOptions()

    /// The vault home slice (read by the home only).
    @Entry var passYHomeLayout = PassYLayoutPreferences.Home()
}

extension View {
    /// Applies the device's layout preferences to this page: sets the environment values the rows read.
    ///
    /// - Parameter store: The preferences (default: the app's).
    ///
    func passYLayoutEnvironment(_ store: PassYLayoutStore = .shared) -> some View {
        modifier(PassYLayoutEnvironmentModifier(store: store))
    }
}

/// Reads the store (observation tracks exactly the slices read here) and sets the environment values.
private struct PassYLayoutEnvironmentModifier: ViewModifier {
    let store: PassYLayoutStore

    func body(content: Content) -> some View {
        let rows = store.rows
        let codes = store.codes
        content
            .environment(\.passYRowOptions, PassYRowOptions(
                density: rows.density,
                showsSubtitle: rows.showsSubtitle,
                showsIcon: rows.showsIcon,
            ))
            .environment(\.passYBadgeOptions, PassYBadgeOptions(
                favorite: rows.showsFavoriteBadge,
                shared: rows.showsSharedBadge,
                attachments: rows.showsAttachmentBadge,
            ))
            .environment(\.passYTileColors, rows.tileColors)
            .environment(\.passYCodeOptions, PassYCodeOptions(
                groupsDigits: codes.groupsDigits,
                showsRing: codes.showsCountdownRing,
                showsSeconds: codes.showsCountdownSeconds,
            ))
            .environment(\.passYHomeLayout, store.home)
    }
}
