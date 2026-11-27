import BitwardenSdk
import XCTest

@testable import BitwardenShared

/// App hygiene checks that need no UI (formerly `PassYUiR9Tests`): the launch screen, the preload hand-over, the
/// release hygiene of the perf hooks, no web vault links, the restored watch targets.
class PassYAppHygieneTests: BitwardenTestCase {
    /// The repository root, found from this file (`#filePath` is in the checkout, which the simulator shares).
    private var root: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relative: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// The launch screen is a plain system background: no logo, no title, no image view.
    func test_launchScreen_isPlain() throws {
        let storyboard = try read("Bitwarden/Application/Support/Resources/LaunchScreen.storyboard")
        XCTAssertFalse(storyboard.contains("imageView"), "no logo")
        XCTAssertFalse(storyboard.contains("logoBitwarden"))
        XCTAssertFalse(storyboard.contains("<label"), "no title")
        XCTAssertTrue(storyboard.contains("systemBackgroundColor"), "neutral system background")
    }

    /// The spec includes the restored watch targets and the Mac and visionOS "Designed for iPad" support is off.
    func test_projectSpec_watchRestored_noMacNoVision() throws {
        let spec = try read("project-pm.yml")
        XCTAssertTrue(spec.contains("BitwardenWatchApp"), "watch app target present")
        XCTAssertTrue(spec.contains("watchOS"))
        XCTAssertTrue(spec.contains("SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO"))
        XCTAssertTrue(spec.contains("SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO"))
        XCTAssertTrue(spec.contains("TARGETED_DEVICE_FAMILY: \"1,2\""))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("BitwardenWatchApp").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("BitwardenWatchShared").path))
    }

    /// The iCloud key-value entitlement (layout sync) belongs to the main app only.
    func test_iCloudKeyValueEntitlement_mainAppOnly() throws {
        let key = "com.apple.developer.ubiquity-kvstore-identifier"
        let app = try read("Bitwarden/Application/Support/Bitwarden.entitlements")
        XCTAssertTrue(app.contains("<key>\(key)</key>\n\t<string>$(TeamIdentifierPrefix)$(BASE_BUNDLE_ID)</string>"))
        for path in [
            "BitwardenActionExtension/Application/Support/BitwardenActionExtension.entitlements",
            "BitwardenAutoFillExtension/Application/Support/BitwardenAutoFill.entitlements",
            "BitwardenNotificationExtension/Application/Support/BitwardenNotificationExtension.entitlements",
            "BitwardenShareExtension/Application/Support/BitwardenShareExtension.entitlements",
        ] {
            XCTAssertFalse(try read(path).contains(key), path)
        }
    }

    /// The diagnostics (perf signposts and counters, animation dump, navigation probe) live in one folder and exist only
    /// in DEBUG builds: every file is one `#if DEBUG` block without an `#else` (no release stubs, no release symbols).
    func test_diagnostics_onlyInDebug() throws {
        let folder = "BitwardenKit/UI/Platform/Application/Diagnostics"
        let files = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path)
            .filter { $0.hasSuffix(".swift") }
        XCTAssertEqual(Set(files), [
            "PassYAnimationDump.swift", "PassYNavigationProbe.swift", "PassYPerf.swift", "PassYStartupTimeline.swift",
            "PassYTouchProbe.swift",
        ])
        for file in files {
            let source = try read("\(folder)/\(file)").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(source.hasPrefix("#if DEBUG"), file)
            XCTAssertTrue(source.hasSuffix("#endif"), file)
            XCTAssertFalse(source.contains("#else"), file)
        }
        XCTAssertTrue(try read("\(folder)/PassYPerf.swift").contains("signposter"))
    }

    /// No production source opens the web vault from a button any more.
    func test_noWebVaultLinks() throws {
        for file in [
            "BitwardenShared/UI/Platform/Settings/Settings/About/AboutProcessor.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/About/AboutView.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/AccountSecurity/AccountSecurityProcessor.swift",
            "BitwardenShared/UI/Platform/Settings/Settings/Vault/VaultSettingsProcessor.swift",
            "BitwardenShared/UI/Auth/Login/TwoFactorAuth/TwoFactorAuthProcessor.swift",
        ] {
            let source = try read(file)
            // (the Duo callback of the two-factor page still needs the server's web vault base URL; it is no link)
            if !file.contains("TwoFactorAuth") { XCTAssertFalse(source.contains("webVaultURL"), file) }
            XCTAssertFalse(source.contains("importItemsURL"), file)
            XCTAssertFalse(source.contains("recoveryCodeURL"), file)
            XCTAssertFalse(source.contains("twoStepLoginUrl"), file)
        }
    }

    /// The preloaded item state is handed over once and expires (no decrypted data stays around).
    @MainActor
    func test_preloadCache_takeOnce_andExpires() {
        ViewItemPreloadCache.clear()
        let state = ViewItemState()
        ViewItemPreloadCache.store(state, id: "a")
        XCTAssertNotNil(ViewItemPreloadCache.take(id: "a"))
        XCTAssertNil(ViewItemPreloadCache.take(id: "a"), "taken once")

        ViewItemPreloadCache.store(state, id: "b", date: Date().addingTimeInterval(-ViewItemPreloadCache.lifetime - 1))
        XCTAssertNil(ViewItemPreloadCache.take(id: "b"), "expired")
    }

    /// The server text of the menus is the URL without a trailing slash.
    func test_serverText() throws {
        XCTAssertEqual(try XCTUnwrap(URL(string: "https://vault.example.com/")).passYServerText, "https://vault.example.com")
        XCTAssertEqual(try XCTUnwrap(URL(string: "http://localhost:8089")).passYServerText, "http://localhost:8089")
    }
}
