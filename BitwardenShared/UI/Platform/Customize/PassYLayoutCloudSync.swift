import BitwardenKit
import Foundation
import OSLog
import UIKit

// MARK: - PassYUbiquitousStore

/// The part of `NSUbiquitousKeyValueStore` the layout sync uses (a fake in the tests).
protocol PassYUbiquitousStore: AnyObject {
    /// The data stored for a key.
    func data(forKey key: String) -> Data?

    /// Stores data for a key.
    func set(_ data: Data?, forKey key: String)

    /// Asks the system to exchange pending changes.
    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: PassYUbiquitousStore {}

// MARK: - Notification.Name

extension Notification.Name {
    /// The app-wide "Show website icons" setting changed (`StateService.setShowWebIcons`); the new value is in the
    /// user info under `PassYLayoutCloudSync.showWebIconsKey`.
    static let passYShowWebIconsDidChange = Notification.Name("passYShowWebIconsDidChange")
}

// MARK: - PassYLayoutCloudSyncing

/// The "Sync layout with iCloud" setting of this device.
@MainActor
protocol PassYLayoutCloudSyncing: AnyObject {
    /// Whether the sync is switched on (stored per device, never synced).
    var isEnabled: Bool { get }

    /// Switches the sync on or off.
    func setEnabled(_ enabled: Bool)
}

// MARK: - PassYLayoutCloudPayload

/// What is stored in iCloud: the Customize settings (the layout preferences and the "Show website icons" switch) and
/// when they were last changed by the user. No vault data and no account data (see `PassYLayoutPreferences`).
struct PassYLayoutCloudPayload: Codable, Equatable {
    /// The version of this envelope written by this app.
    static let currentSchema = 1

    /// The version of the envelope.
    var schema = Self.currentSchema

    /// When the user last changed this layout.
    var modifiedAt: Date

    /// The layout.
    var layout: PassYLayoutPreferences

    /// The app-wide "Show website icons" switch (also on the Customize page). `nil` in payloads of earlier builds:
    /// then the local value is left alone.
    var showWebIcons: Bool?
}

// MARK: - PassYLayoutCloudValue

/// What iCloud holds for the layout.
enum PassYLayoutCloudValue: Equatable {
    /// Nothing.
    case missing

    /// Something that is not a layout: it may be overwritten.
    case broken

    /// Written by a newer app: it is neither applied nor overwritten.
    case newer

    /// A layout this app understands.
    case payload(PassYLayoutCloudPayload)

    /// Reads stored data. The preferences decode leniently (a missing field takes its default), so the shape and
    /// the versions are checked first: a broken payload must never turn into "the defaults".
    init(data: Data?) {
        guard let data else {
            self = .missing
            return
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = object["schema"] as? Int else {
            self = .broken
            return
        }
        let layout = object["layout"] as? [String: Any]
        let version = layout?["version"] as? Int
        if schema > PassYLayoutCloudPayload.currentSchema
            || (version ?? 0) > PassYLayoutPreferences.currentVersion {
            self = .newer
            return
        }
        guard version != nil,
              ["home", "rows", "codes"].allSatisfy({ layout?[$0] is [String: Any] }),
              let payload = try? JSONDecoder().decode(PassYLayoutCloudPayload.self, from: data) else {
            self = .broken
            return
        }
        self = .payload(payload)
    }
}

// MARK: - PassYLayoutCloudSync

/// Mirrors the Customize settings into the user's iCloud key-value store: the layout preferences (`PassYLayoutStore`,
/// which stays what the UI reads, backed by the app group settings) and the app-wide "Show website icons" switch
/// (`StateService`, shown on Customize and in Appearance). Off by default; the switch is per device. Only the main app
/// starts it, and app extensions get no iCloud store at all.
///
/// Who wins:
/// - Switched on (and when iCloud reports its first download or another iCloud account): a layout in iCloud is
///   applied to this device. Without one, this device's layout is uploaded.
/// - While on (launch, foreground, changes from other devices): the newer modification date wins; an older iCloud
///   layout is replaced by this device's.
/// - A layout the user never touched (the defaults without a modification date, website icons on) is never uploaded:
///   it holds nothing and must not replace a real layout of another device.
/// - Website icons travel with the layout and its date. A payload without the switch (an earlier build) leaves the
///   local value alone.
/// - A layout of a newer app is left alone in both directions.
/// - The local layout is never removed. Switching off leaves both copies as they are.
///
@MainActor
public final class PassYLayoutCloudSync: PassYLayoutCloudSyncing {
    // MARK: Static

    /// The key of the layout in the iCloud key-value store.
    nonisolated static let key = "passYLayout"

    /// The user info key of the value in `passYShowWebIconsDidChange`.
    nonisolated static let showWebIconsKey = "showWebIcons"

    /// The sync of the app.
    public static let shared = PassYLayoutCloudSync(
        layout: .shared,
        appSettingsStore: PassYLayoutStore.appGroupSettingsStore(),
        makeCloudStore: { PassYLayoutCloudSync.systemStore(bundleURL: Bundle.main.bundleURL) },
    )

    /// The system's iCloud key-value store, `nil` in an app extension (no entitlement, and no sync there).
    static func systemStore(bundleURL: URL) -> (any PassYUbiquitousStore)? {
        bundleURL.pathExtension == "appex" ? nil : NSUbiquitousKeyValueStore.default
    }

    // MARK: Properties

    /// Where the switch, the modification date and the website icons setting are stored.
    private let appSettingsStore: any AppSettingsStore

    /// Writes a website icons value from iCloud through the app's state service, so open screens update. Without
    /// it (tests, before `start(services:)`) the stored setting is written directly.
    var applyShowWebIcons: ((Bool) -> Void)?

    /// Whether a layout from iCloud is being written into the local store (not a change of the user).
    private var isApplyingRemote = false

    /// The local layout.
    private let layout: PassYLayoutStore

    /// Creates the iCloud store.
    private let makeCloudStore: () -> (any PassYUbiquitousStore)?

    /// The iCloud store, created when it is first needed (never while the sync is off).
    private lazy var cloudStore: (any PassYUbiquitousStore)? = makeCloudStore()

    /// The center the notifications arrive on.
    private let notificationCenter: NotificationCenter

    /// The current date.
    private let now: () -> Date

    /// The notification observers while the sync is on.
    private var observers: [any NSObjectProtocol] = []

    /// The observer of the website icons setting (always: a change is dated even while the sync is off).
    private var webIconsObserver: (any NSObjectProtocol)?

    // MARK: Initialization

    /// Creates the sync.
    ///
    /// - Parameters:
    ///   - layout: The local layout.
    ///   - appSettingsStore: Where the switch and the modification date are stored.
    ///   - makeCloudStore: Creates the iCloud store (`nil`: none available).
    ///   - notificationCenter: The center the notifications arrive on.
    ///   - now: The current date.
    ///
    init(
        layout: PassYLayoutStore,
        appSettingsStore: any AppSettingsStore,
        makeCloudStore: @escaping () -> (any PassYUbiquitousStore)?,
        notificationCenter: NotificationCenter = .default,
        now: @escaping () -> Date = { Date() },
    ) {
        self.layout = layout
        self.appSettingsStore = appSettingsStore
        self.makeCloudStore = makeCloudStore
        self.notificationCenter = notificationCenter
        self.now = now
        layout.onChange = { [weak self] in self?.localLayoutDidChange() }
        webIconsObserver = notificationCenter.addObserver(
            forName: .passYShowWebIconsDidChange,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            guard let value = notification.userInfo?[Self.showWebIconsKey] as? Bool else { return }
            MainActor.assumeIsolated {
                self?.localWebIconsDidChange(value)
            }
        }
    }

    // MARK: Methods

    var isEnabled: Bool { appSettingsStore.passYLayoutCloudSyncEnabled }

    /// Call once when the main app launches, after the services exist: connects the website icons setting and resumes
    /// the sync if it is switched on (otherwise it only listens for local changes).
    ///
    /// - Parameter services: The app's services.
    ///
    public func start(services: ServiceContainer) {
        let stateService = services.stateService
        applyShowWebIcons = { value in
            Task { await stateService.setShowWebIcons(value) }
        }
        start()
    }

    /// Resumes the sync if it is switched on, otherwise does nothing.
    func start() {
        guard isEnabled else { return }
        observe()
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        appSettingsStore.passYLayoutCloudSyncEnabled = enabled
        if enabled {
            observe()
            cloudStore?.synchronize()
            adoptCloud()
        } else {
            observers.forEach(notificationCenter.removeObserver)
            observers = []
        }
    }

    // MARK: Private Methods

    /// The iCloud layout wins, without one this device's is uploaded.
    private func adoptCloud() {
        guard let cloudStore else { return }
        switch PassYLayoutCloudValue(data: cloudStore.data(forKey: Self.key)) {
        case let .payload(payload):
            apply(payload)
        case .broken, .missing:
            upload()
        case .newer:
            break
        }
    }

    /// Exchanges changes: the newer of the two layouts wins.
    private func reconcile() {
        guard let cloudStore else { return }
        switch PassYLayoutCloudValue(data: cloudStore.data(forKey: Self.key)) {
        case let .payload(payload):
            let local = appSettingsStore.passYLayoutModifiedAt ?? .distantPast
            if payload.modifiedAt > local {
                apply(payload)
            } else if payload.modifiedAt < local {
                upload()
            }
        case .broken, .missing:
            upload()
        case .newer:
            break
        }
    }

    /// Launch and foreground.
    private func refresh() {
        cloudStore?.synchronize()
        reconcile()
    }

    /// Writes an iCloud layout into the local store. It keeps its date, so it is not uploaded again.
    private func apply(_ payload: PassYLayoutCloudPayload) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        appSettingsStore.passYLayoutModifiedAt = payload.modifiedAt
        layout.preferences = payload.layout
        // An earlier build's payload has no website icons value: the local one stays.
        if let showWebIcons = payload.showWebIcons, showWebIcons != self.showWebIcons {
            if let applyShowWebIcons {
                // Asynchronous (state service): its change notification comes back later and is recognized as
                // the value iCloud already holds (`localWebIconsDidChange`).
                applyShowWebIcons(showWebIcons)
            } else {
                appSettingsStore.disableWebIcons = !showWebIcons
            }
        }
    }

    /// The local website icons setting.
    private var showWebIcons: Bool { !appSettingsStore.disableWebIcons }

    /// Writes this device's layout to iCloud (unless the user never touched it).
    private func upload() {
        guard let cloudStore,
              appSettingsStore.passYLayoutModifiedAt != nil || !layout.isDefault || !showWebIcons else { return }
        // A layout customized before the date was recorded counts from now.
        let modifiedAt = appSettingsStore.passYLayoutModifiedAt ?? now()
        appSettingsStore.passYLayoutModifiedAt = modifiedAt
        let payload = PassYLayoutCloudPayload(
            modifiedAt: modifiedAt,
            layout: layout.preferences,
            showWebIcons: showWebIcons,
        )
        do {
            try cloudStore.set(JSONEncoder().encode(payload), forKey: Self.key)
        } catch {
            Logger.application.error("Pass-Y layout: could not encode for iCloud: \(error)")
        }
    }

    /// A change made by the user: dates it, and uploads it while the sync is on.
    private func localLayoutDidChange() {
        guard !isApplyingRemote else { return }
        let cloud = isEnabled ? cloudStore.map { PassYLayoutCloudValue(data: $0.data(forKey: Self.key)) } : nil
        // Later than every date seen so far, also when this device's clock is behind the one of another device.
        var latest = appSettingsStore.passYLayoutModifiedAt ?? .distantPast
        if case let .payload(payload) = cloud {
            latest = max(latest, payload.modifiedAt)
        }
        appSettingsStore.passYLayoutModifiedAt = max(now(), latest.addingTimeInterval(0.001))
        if isEnabled, cloud != .newer {
            upload()
        }
    }

    /// A change of the website icons setting (Customize or Appearance). The value iCloud already holds is not a new
    /// change: it is the echo of a value applied from iCloud, or nothing to upload.
    private func localWebIconsDidChange(_ value: Bool) {
        guard !isApplyingRemote else { return }
        if isEnabled, let cloudStore,
           case let .payload(payload) = PassYLayoutCloudValue(data: cloudStore.data(forKey: Self.key)),
           payload.showWebIcons == value {
            return
        }
        localLayoutDidChange()
    }

    /// Observes changes from iCloud and the app coming to the foreground.
    private func observe() {
        guard observers.isEmpty, cloudStore != nil else { return }
        observers = [
            notificationCenter.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: nil,
                queue: .main,
            ) { [weak self] notification in
                let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
                let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                MainActor.assumeIsolated {
                    self?.cloudDidChange(reason: reason, keys: keys)
                }
            },
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main,
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            },
        ]
    }

    /// `NSUbiquitousKeyValueStore.didChangeExternallyNotification`.
    private func cloudDidChange(reason: Int?, keys: [String]) {
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:
            if keys.contains(Self.key) { reconcile() }
        case NSUbiquitousKeyValueStoreAccountChange, NSUbiquitousKeyValueStoreInitialSyncChange:
            // The first download (earlier writes were discarded) or another account: like switching on.
            adoptCloud()
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            Logger.application.warning("Pass-Y layout: iCloud key-value quota exceeded, the layout stays local")
        default:
            break
        }
    }
}
