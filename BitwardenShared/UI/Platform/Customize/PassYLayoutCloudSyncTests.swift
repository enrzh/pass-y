import BitwardenKit
import UIKit
import XCTest

@testable import BitwardenShared

// MARK: - PassYLayoutCloudSyncTests

class PassYLayoutCloudSyncTests: BitwardenTestCase {
    // MARK: Properties

    var appSettingsStore: MockAppSettingsStore!
    var cloud: FakeUbiquitousStore!
    var cloudStoresMade = 0
    var date: Date!
    var layout: PassYLayoutStore!
    var notificationCenter: NotificationCenter!
    var subject: PassYLayoutCloudSync!

    // MARK: Setup & Teardown

    @MainActor
    override func setUp() {
        super.setUp()
        appSettingsStore = MockAppSettingsStore()
        cloud = FakeUbiquitousStore()
        cloudStoresMade = 0
        date = Date(timeIntervalSinceReferenceDate: 1000)
        notificationCenter = NotificationCenter()
        makeSubject()
    }

    override func tearDown() {
        super.tearDown()
        appSettingsStore = nil
        cloud = nil
        date = nil
        layout = nil
        notificationCenter = nil
        subject = nil
    }

    // MARK: Helpers

    /// A layout that differs from the defaults.
    private var filled: PassYLayoutPreferences {
        var preferences = PassYLayoutPreferences.default
        preferences.home.cardColors = .filled
        preferences.home.folderCards = ["folder:only-on-another-device"]
        return preferences
    }

    /// Another layout that differs from the defaults.
    private var minimal: PassYLayoutPreferences {
        var preferences = PassYLayoutPreferences.default
        preferences.rows.showsIcon = false
        preferences.codes.groupsDigits = false
        return preferences
    }

    /// (Re)creates the local store and the sync on the same settings, like a launch.
    @MainActor
    private func makeSubject() {
        layout = PassYLayoutStore(appSettingsStore: appSettingsStore)
        subject = PassYLayoutCloudSync(
            layout: layout,
            appSettingsStore: appSettingsStore,
            makeCloudStore: { [weak self] in
                self?.cloudStoresMade += 1
                return self?.cloud
            },
            notificationCenter: notificationCenter,
            now: { [weak self] in self?.date ?? .distantPast },
        )
    }

    /// Stores a layout in the fake iCloud, changed at `seconds`.
    private func putCloud(_ preferences: PassYLayoutPreferences, at seconds: TimeInterval) throws {
        cloud.values[PassYLayoutCloudSync.key] = try JSONEncoder().encode(PassYLayoutCloudPayload(
            modifiedAt: Date(timeIntervalSinceReferenceDate: seconds),
            layout: preferences,
        ))
    }

    /// What the fake iCloud holds.
    private var cloudPayload: PassYLayoutCloudPayload? {
        guard case let .payload(payload) = PassYLayoutCloudValue(data: cloud.values[PassYLayoutCloudSync.key]) else {
            return nil
        }
        return payload
    }

    /// Posts the system's "changed externally" notification.
    private func postChange(_ reason: Int, keys: [String] = [PassYLayoutCloudSync.key]) {
        notificationCenter.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            userInfo: [
                NSUbiquitousKeyValueStoreChangeReasonKey: reason,
                NSUbiquitousKeyValueStoreChangedKeysKey: keys,
            ],
        )
    }

    // MARK: Tests

    /// Off by default: launch, foreground, notifications and local changes do not touch iCloud (it is not even
    /// created); a reinstall gets nothing until the user switches it on.
    @MainActor
    func test_off_doesNothing() throws {
        try putCloud(filled, at: 500)
        XCTAssertFalse(subject.isEnabled)

        subject.start()
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        postChange(NSUbiquitousKeyValueStoreServerChange)
        XCTAssertEqual(layout.preferences, .default)

        layout.preferences = minimal
        XCTAssertEqual(cloudStoresMade, 0)
        XCTAssertEqual(cloud.writes, 0)
        XCTAssertEqual(cloudPayload?.layout, filled)
        XCTAssertNotNil(appSettingsStore.passYLayoutModifiedAt, "the change is dated for later")
    }

    /// Switching on with a layout in iCloud applies it, also when this device's is newer, and does not upload.
    @MainActor
    func test_enable_cloudWins() throws {
        layout.preferences = minimal
        try putCloud(filled, at: 10)

        subject.setEnabled(true)

        XCTAssertTrue(subject.isEnabled)
        XCTAssertTrue(appSettingsStore.passYLayoutCloudSyncEnabled)
        XCTAssertEqual(layout.preferences, filled)
        XCTAssertEqual(appSettingsStore.passYLayoutPreferences, filled)
        XCTAssertEqual(appSettingsStore.passYLayoutModifiedAt, Date(timeIntervalSinceReferenceDate: 10))
        XCTAssertEqual(cloud.writes, 0)
        XCTAssertEqual(cloud.synchronizations, 1)
    }

    /// Switching on without a layout in iCloud uploads this device's, with the date of its last change.
    @MainActor
    func test_enable_uploadsLocal() {
        layout.preferences = minimal
        let changed = appSettingsStore.passYLayoutModifiedAt
        date = Date(timeIntervalSinceReferenceDate: 2000)

        subject.setEnabled(true)

        XCTAssertEqual(cloudPayload?.layout, minimal)
        XCTAssertEqual(cloudPayload?.modifiedAt, changed)
        XCTAssertEqual(layout.preferences, minimal)
    }

    /// A layout customized before changes were dated is uploaded and dated now.
    @MainActor
    func test_enable_uploadsUndatedCustomLayout() {
        appSettingsStore.passYLayoutPreferences = minimal
        makeSubject()

        subject.setEnabled(true)

        XCTAssertEqual(cloudPayload?.layout, minimal)
        XCTAssertEqual(cloudPayload?.modifiedAt, date)
        XCTAssertEqual(appSettingsStore.passYLayoutModifiedAt, date)
    }

    /// An untouched layout is not uploaded; a layout of another device arriving later is applied.
    @MainActor
    func test_enable_untouchedLayout_notUploaded() throws {
        subject.setEnabled(true)
        XCTAssertEqual(cloud.writes, 0)

        try putCloud(filled, at: 10)
        postChange(NSUbiquitousKeyValueStoreServerChange)

        XCTAssertEqual(layout.preferences, filled)
        XCTAssertEqual(cloud.writes, 0)
    }

    /// While on, a change of the user is uploaded; resetting to the defaults is a change too.
    @MainActor
    func test_localChange_uploads() {
        subject.setEnabled(true)

        layout.home.cardColors = .filled
        XCTAssertEqual(cloudPayload?.layout.home.cardColors, .filled)
        XCTAssertEqual(cloudPayload?.modifiedAt, date)

        date = Date(timeIntervalSinceReferenceDate: 2000)
        layout.reset()
        XCTAssertEqual(cloudPayload?.layout, .default)
        XCTAssertEqual(cloudPayload?.modifiedAt, date)
    }

    /// A change on a device whose clock is behind is still dated after the layout it replaces.
    @MainActor
    func test_localChange_clockBehind() throws {
        try putCloud(filled, at: 5000)
        subject.setEnabled(true)

        layout.rows.showsIcon = false

        let uploaded = try XCTUnwrap(cloudPayload)
        XCTAssertGreaterThan(uploaded.modifiedAt, Date(timeIntervalSinceReferenceDate: 5000))
        XCTAssertFalse(uploaded.layout.rows.showsIcon)
        XCTAssertEqual(uploaded.modifiedAt, appSettingsStore.passYLayoutModifiedAt)
    }

    /// A newer layout from another device is applied and not echoed back.
    @MainActor
    func test_serverChange_newerApplied() throws {
        layout.preferences = minimal
        subject.setEnabled(true)
        let writes = cloud.writes

        try putCloud(filled, at: 3000)
        postChange(NSUbiquitousKeyValueStoreServerChange)

        XCTAssertEqual(layout.preferences, filled)
        XCTAssertEqual(appSettingsStore.passYLayoutModifiedAt, Date(timeIntervalSinceReferenceDate: 3000))
        XCTAssertEqual(cloud.writes, writes)

        // The same value again changes nothing.
        postChange(NSUbiquitousKeyValueStoreServerChange)
        XCTAssertEqual(cloud.writes, writes)
    }

    /// A stale layout from iCloud does not overwrite a newer local change; this device's replaces it.
    @MainActor
    func test_serverChange_staleReplaced() throws {
        subject.setEnabled(true)
        layout.preferences = minimal

        try putCloud(filled, at: 10)
        postChange(NSUbiquitousKeyValueStoreServerChange)

        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloudPayload?.layout, minimal)
        XCTAssertEqual(cloudPayload?.modifiedAt, appSettingsStore.passYLayoutModifiedAt)
    }

    /// Changes of other keys are ignored.
    @MainActor
    func test_serverChange_otherKey() throws {
        subject.setEnabled(true)
        try putCloud(filled, at: 3000)

        postChange(NSUbiquitousKeyValueStoreServerChange, keys: ["other"])

        XCTAssertEqual(layout.preferences, .default)
    }

    /// Launch and foreground synchronize and apply a newer layout.
    @MainActor
    func test_launchAndForeground() throws {
        appSettingsStore.passYLayoutCloudSyncEnabled = true
        try putCloud(filled, at: 10)
        makeSubject()

        subject.start()
        XCTAssertEqual(layout.preferences, filled)
        XCTAssertEqual(cloud.synchronizations, 1)

        try putCloud(minimal, at: 20)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloud.synchronizations, 2)
        XCTAssertEqual(cloud.writes, 0)
    }

    /// At launch an older layout in iCloud does not win.
    @MainActor
    func test_launch_localNewer() throws {
        appSettingsStore.passYLayoutCloudSyncEnabled = true
        appSettingsStore.passYLayoutPreferences = minimal
        appSettingsStore.passYLayoutModifiedAt = Date(timeIntervalSinceReferenceDate: 100)
        try putCloud(filled, at: 10)
        makeSubject()

        subject.start()

        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloudPayload?.layout, minimal)
    }

    /// Switching off leaves both copies; later changes on either side are not exchanged.
    @MainActor
    func test_disable() throws {
        layout.preferences = minimal
        subject.setEnabled(true)

        subject.setEnabled(false)
        XCTAssertFalse(subject.isEnabled)
        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloudPayload?.layout, minimal)
        let writes = cloud.writes

        layout.home.cardColors = .filled
        try putCloud(.default, at: 9000)
        postChange(NSUbiquitousKeyValueStoreServerChange)
        postChange(NSUbiquitousKeyValueStoreAccountChange)
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertEqual(layout.home.cardColors, .filled)
        XCTAssertFalse(layout.rows.showsIcon)
        XCTAssertEqual(cloud.writes, writes)
    }

    /// Another iCloud account or the first download: like switching on, also with an older date; without a layout
    /// there, the local one is kept and uploaded.
    @MainActor
    func test_accountChangeAndInitialSync() throws {
        layout.preferences = minimal
        subject.setEnabled(true)

        cloud.values = [:]
        postChange(NSUbiquitousKeyValueStoreAccountChange, keys: [])
        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloudPayload?.layout, minimal)

        try putCloud(filled, at: 1)
        postChange(NSUbiquitousKeyValueStoreInitialSyncChange)
        XCTAssertEqual(layout.preferences, filled)

        try putCloud(.default, at: 0)
        postChange(NSUbiquitousKeyValueStoreAccountChange)
        XCTAssertEqual(layout.preferences, .default)
    }

    /// A quota violation changes nothing on either side.
    @MainActor
    func test_quotaViolation() throws {
        layout.preferences = minimal
        subject.setEnabled(true)
        try putCloud(filled, at: 9000)
        let writes = cloud.writes

        postChange(NSUbiquitousKeyValueStoreQuotaViolationChange)

        XCTAssertEqual(layout.preferences, minimal)
        XCTAssertEqual(cloud.writes, writes)
        XCTAssertTrue(subject.isEnabled)
    }

    /// A layout of a newer app is neither applied nor overwritten.
    @MainActor
    func test_newerPayload_untouched() {
        for json in [
            #"{"schema":2,"somethingElse":true}"#,
            #"{"schema":1,"modifiedAt":9000,"layout":{"version":3,"home":{},"rows":{},"codes":{}}}"#,
        ] {
            let data = Data(json.utf8)
            XCTAssertEqual(PassYLayoutCloudValue(data: data), .newer, json)
            cloud.values[PassYLayoutCloudSync.key] = data
            layout.preferences = minimal

            subject.setEnabled(true)
            layout.home.cardColors = .filled
            postChange(NSUbiquitousKeyValueStoreServerChange)
            postChange(NSUbiquitousKeyValueStoreAccountChange)
            notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil)

            XCTAssertEqual(layout.home.cardColors, .filled, json)
            XCTAssertFalse(layout.rows.showsIcon, json)
            XCTAssertEqual(cloud.values[PassYLayoutCloudSync.key], data, json)
            XCTAssertEqual(cloud.writes, 0, json)

            subject.setEnabled(false)
            layout.reset()
        }
    }

    /// A broken payload never becomes the defaults: the local layout stays and replaces it.
    @MainActor
    func test_brokenPayload_localKept() {
        for json in [
            "garbage",
            "[]",
            "{}",
            #"{"schema":1}"#,
            #"{"schema":1,"modifiedAt":9000,"layout":{}}"#,
            #"{"schema":1,"modifiedAt":9000,"layout":{"version":2,"home":5,"rows":{},"codes":{}}}"#,
            #"{"schema":1,"layout":{"version":2,"home":{},"rows":{},"codes":{}}}"#,
        ] {
            let data = Data(json.utf8)
            XCTAssertEqual(PassYLayoutCloudValue(data: data), .broken, json)
            layout.preferences = minimal
            cloud.values[PassYLayoutCloudSync.key] = data

            subject.setEnabled(true)

            XCTAssertEqual(layout.preferences, minimal, json)
            XCTAssertEqual(cloudPayload?.layout, minimal, json)
            subject.setEnabled(false)
        }
    }

    /// A payload of version 1 of the preferences is migrated.
    func test_olderPayload_migrated() {
        let json = #"{"schema":1,"modifiedAt":1,"layout":{"version":1,"home":{"hiddenTiles":["trash"]},"#
            + #""rows":{},"codes":{}}}"#
        guard case let .payload(payload) = PassYLayoutCloudValue(data: Data(json.utf8)) else {
            return XCTFail("not read")
        }
        XCTAssertEqual(payload.layout.home.tileRows, ["trash"])
        XCTAssertEqual(payload.layout.version, PassYLayoutPreferences.currentVersion)
    }

    /// App extensions get no iCloud store; the app gets the system's.
    @MainActor
    func test_systemStore_onlyOutsideExtensions() {
        XCTAssertNil(PassYLayoutCloudSync.systemStore(bundleURL: URL(fileURLWithPath: "/App.app/PlugIns/Fill.appex")))
        XCTAssertNotNil(PassYLayoutCloudSync.systemStore(bundleURL: URL(fileURLWithPath: "/App.app")))
    }
}

// MARK: - FakeUbiquitousStore

/// An in-memory iCloud key-value store.
class FakeUbiquitousStore: PassYUbiquitousStore {
    var synchronizations = 0
    var values: [String: Data] = [:]
    var writes = 0

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func set(_ data: Data?, forKey key: String) {
        writes += 1
        values[key] = data
    }

    func synchronize() -> Bool {
        synchronizations += 1
        return true
    }
}

// MARK: - MockPassYLayoutCloudSync

@MainActor
class MockPassYLayoutCloudSync: PassYLayoutCloudSyncing {
    var isEnabled = false
    var setEnabledValues: [Bool] = []

    func setEnabled(_ enabled: Bool) {
        setEnabledValues.append(enabled)
        isEnabled = enabled
    }
}
