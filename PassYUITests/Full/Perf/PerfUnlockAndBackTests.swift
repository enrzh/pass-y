import Darwin
import XCTest

/// Start and navigation latency against the 2000 item perf account (`PASSY_EMAIL=passy-perf@example.test`). Prints
/// `R8CMP <name> n=... median=...` like `PerfCompareTests`, so before/after runs compare line by line.
///
/// - Face ID unlock (cold launch and return from the background) until the first vault row exists, plus how long the
///   screen showed no content (a blank, launch-screen colored frame) after the Face ID match.
/// - Back (top left) from a pushed page until the previous page is shown again.
///
/// The class sorts after `PerfTests` on purpose: the Face ID test leaves Face ID unlock and the "Immediately" timeout on.
final class PerfUnlockAndBackTests: PassYUITestCase {
    // MARK: Face ID

    /// Cold launch with Face ID: terminate, launch, the app asks for Face ID by itself, the simulator matches; the clock
    /// starts at the match. Five runs, then the same from the background (session timeout "Immediately").
    func test_cmp_faceIdUnlockToFirstRow() {
        let app = launchApp()
        ensureUnlockedVault(app)
        enableFaceIdUnlock(app)

        var coldRows: [Double] = []
        var coldBlank: [Double] = []
        for run in 0 ..< 5 {
            app.terminate()
            app.launch()
            let (row, blank) = matchFaceIdAndMeasure(app, name: "cold-\(run)")
            coldRows.append(row)
            coldBlank.append(blank)
        }
        line("faceid_cold_to_first_row", coldRows)
        line("faceid_cold_blank_after_match", coldBlank)

        // Return from the background: the vault locks immediately when the app leaves the foreground.
        setSessionTimeoutImmediately(app)
        var warmRows: [Double] = []
        var warmBlank: [Double] = []
        for run in 0 ..< 5 {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.wait(for: .runningBackgroundSuspended, timeout: 5))
            sleep(1)
            app.activate()
            let (row, blank) = matchFaceIdAndMeasure(app, name: "warm-\(run)")
            warmRows.append(row)
            warmBlank.append(blank)
        }
        line("faceid_background_to_first_row", warmRows)
        line("faceid_background_blank_after_match", warmBlank)
        // Face ID off again: the class sorts last in the perf step, but a rerun of single tests types the password.
        app.terminate()
        setFaceIdEnrolled(false)
    }

    // MARK: Back

    /// Category tile (2000 logins) -> back: from the back tap until the vault home tile exists again (`home`) and until
    /// the group's rows are gone and the app is idle (`settled`).
    func test_cmp_backFromGroup() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let tile = app.buttons["CategoryTile_login"]
        XCTAssertTrue(waitFor(tile, timeout: 60))
        var home: [Double] = []
        var settled: [Double] = []
        let rows = app.buttons.matching(identifier: "VaultListItemRowButton")
        for _ in 0 ..< 10 {
            tile.tap()
            XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20))
            sleep(1)
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            let (h, s) = measureBack(back, home: tile) { !app.navigationBars.buttons["BackButton"].exists && !rows.firstMatch.exists }
            home.append(h)
            settled.append(s)
        }
        line("back_from_group_home_shown", home)
        line("back_from_group_settled", settled)
    }

    /// Settings > Account security -> back (a small page, no list): separates the cost of the shell's pop from the cost
    /// of a big list.
    func test_cmp_backFromSettingsPage() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        let accountSecurity = app.buttons["AccountSecuritySettingsButton"]
        XCTAssertTrue(waitFor(accountSecurity, timeout: 10))
        var home: [Double] = []
        var settled: [Double] = []
        let chooser = app.buttons["VaultTimeoutChooser"]
        for _ in 0 ..< 10 {
            accountSecurity.tap()
            XCTAssertTrue(chooser.waitForExistence(timeout: 10))
            sleep(1)
            let back = app.navigationBars.buttons.firstMatch
            let (h, s) = measureBack(back, home: accountSecurity) { !chooser.exists }
            home.append(h)
            settled.append(s)
        }
        line("back_from_settings_page_shown", home)
        line("back_from_settings_page_settled", settled)
        goTo(app, "My vault")
    }

    // MARK: Helpers

    /// Taps `back` and returns (seconds until `home` exists, seconds until `gone()` holds), polled every 10 ms.
    private func measureBack(_ back: XCUIElement, home: XCUIElement, gone: () -> Bool) -> (Double, Double) {
        let start = Date()
        // Same clock as the app's `startup mark=... t=` log lines (simulator = host clock).
        print("PASSY-MARK backTap t=\(String(format: "%.3f", start.timeIntervalSinceReferenceDate))")
        back.tap()
        var shown: Double?
        let deadline = start.addingTimeInterval(15)
        while Date() < deadline {
            if shown == nil, home.exists { shown = Date().timeIntervalSince(start) }
            if shown != nil, gone(), home.isHittable { break }
            usleep(10000)
        }
        let settled = Date().timeIntervalSince(start)
        XCTAssertNotNil(shown, "previous page shown within 15 s of the back tap")
        return (shown ?? 15, settled)
    }

    /// Settings > Account security: switches "Unlock with Face ID" on (enrolls Face ID in the simulator first).
    private func enableFaceIdUnlock(_ app: XCUIApplication) {
        setFaceIdEnrolled(true)
        goTo(app, "Settings")
        app.buttons["AccountSecuritySettingsButton"].tap()
        let toggle = app.switches["UnlockWithBiometricsSwitch"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Account security offers Face ID unlock\n\(app.debugDescription)")
        if (toggle.value as? String) != "1" {
            toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
            allowFaceIdIfAsked(app)
            postFaceId(match: true)
            XCTAssertTrue(waitUntil(10) { (toggle.value as? String) == "1" }, "Face ID unlock switched on")
        }
        app.navigationBars.buttons.firstMatch.tap()
        goTo(app, "My vault")
    }

    /// Account security: session timeout "Immediately", so the vault locks whenever the app leaves the foreground.
    private func setSessionTimeoutImmediately(_ app: XCUIApplication) {
        app.launch() // a fresh process locked on start: unlock with Face ID once
        _ = matchFaceIdAndMeasure(app, name: "setup")
        goTo(app, "Settings")
        app.buttons["AccountSecuritySettingsButton"].tap()
        let chooser = app.buttons["VaultTimeoutChooser"]
        XCTAssertTrue(chooser.waitForExistence(timeout: 10))
        chooser.tap()
        let immediately = app.buttons["Immediately"]
        XCTAssertTrue(immediately.waitForExistence(timeout: 5), "timeout menu offers Immediately")
        immediately.tap()
        sleep(1)
        app.navigationBars.buttons.firstMatch.tap()
        goTo(app, "My vault")
    }

    /// Waits for the unlock screen, lets the simulator match Face ID, then measures from the match until the first perf
    /// row exists. Meanwhile screenshots are taken back to back; a frame without content (only the page color) counts
    /// as blank. Returns (seconds to the first row, seconds of blank frames after the match).
    private func matchFaceIdAndMeasure(_ app: XCUIApplication, name: String) -> (Double, Double) {
        let unlock = app.buttons["UnlockVaultButton"]
        let password = app.secureTextFields["MasterPasswordEntry"]
        XCTAssertTrue(waitUntil(30) { unlock.exists || password.exists }, "\(name): unlock screen\n\(app.debugDescription)")
        // The app asks for Face ID on its own when the unlock screen appears; give the prompt time to come up.
        sleep(2)
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Perf Item'")).firstMatch
        postFaceId(match: true)
        let start = Date()
        print("PASSY-MARK faceIdMatch \(name) t=\(String(format: "%.3f", start.timeIntervalSinceReferenceDate))")
        var blank: Double = 0
        var lastFrame = start
        var lastBlank = false
        var rowAt: Double?
        let deadline = start.addingTimeInterval(30)
        while Date() < deadline {
            let shot = XCUIScreen.main.screenshot()
            let now = Date()
            if lastBlank { blank += now.timeIntervalSince(lastFrame) }
            lastBlank = isBlankFrame(shot)
            lastFrame = now
            if now.timeIntervalSince(start) < 1.5, lastBlank {
                let attachment = XCTAttachment(screenshot: shot)
                attachment.name = "faceid-\(name)-blank-\(String(format: "%.0f", now.timeIntervalSince(start) * 1000))ms"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            if row.exists { rowAt = Date().timeIntervalSince(start); break }
        }
        XCTAssertNotNil(rowAt, "\(name): no 'Perf Item' row 30 s after the Face ID match\n\(app.debugDescription)")
        print("FACEID \(name) row=\(String(format: "%.3f", rowAt ?? -1)) blank=\(String(format: "%.3f", blank))")
        return (rowAt ?? 30, blank)
    }

    /// The system Face ID permission alert ("Do you want to allow ... to use Face ID?") is answered with OK.
    private func allowFaceIdIfAsked(_ app: XCUIApplication) {
        for alert in [app.alerts.firstMatch, XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch] {
            if alert.waitForExistence(timeout: 2) {
                let ok = alert.buttons["OK"].exists ? alert.buttons["OK"] : alert.buttons.element(boundBy: alert.buttons.count - 1)
                ok.tap()
                return
            }
        }
    }

    /// A frame is blank when (status bar and home indicator excluded) almost no sample differs from the page color.
    private func isBlankFrame(_ shot: XCUIScreenshot) -> Bool {
        guard let cg = shot.image.cgImage else { return false }
        let width = 40, height = 86
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return false }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        func luminance(_ x: Int, _ y: Int) -> Double {
            let i = (y * width + x) * 4
            return (0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])) / 255
        }
        let base = luminance(1, height / 2)
        var differing = 0
        for y in (height * 8 / 100) ..< (height * 95 / 100) {
            for x in 0 ..< width where abs(luminance(x, y) - base) > 0.06 {
                differing += 1
            }
        }
        return differing < 4
    }

    /// Enrolls (or removes) Face ID in the simulator (the simulator shares one Darwin notify namespace; `notify.h` is
    /// not exported to Swift, so the functions are looked up at run time).
    private func setFaceIdEnrolled(_ enrolled: Bool) {
        typealias Register = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> UInt32
        typealias SetState = @convention(c) (Int32, UInt64) -> UInt32
        let handle = dlopen(nil, RTLD_NOW)
        guard let register = dlsym(handle, "notify_register_check"), let setState = dlsym(handle, "notify_set_state") else {
            return XCTFail("notify functions not found")
        }
        var token: Int32 = 0
        _ = unsafeBitCast(register, to: Register.self)("com.apple.BiometricKit.enrollmentChanged", &token)
        _ = unsafeBitCast(setState, to: SetState.self)(token, enrolled ? 1 : 0)
        post("com.apple.BiometricKit.enrollmentChanged")
        sleep(1)
    }

    /// Lets the simulator match (or reject) the face of the running Face ID prompt.
    private func postFaceId(match: Bool) {
        post(match ? "com.apple.BiometricKit_Sim.pearl.match" : "com.apple.BiometricKit_Sim.pearl.nomatch")
    }

    /// Posts a Darwin notification.
    private func post(_ name: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}
