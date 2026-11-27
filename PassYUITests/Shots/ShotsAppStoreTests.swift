import XCTest

/// The App Store screenshots (iPhone 6.9", iPad 13") and a few screens that are checked by eye. Never gating.
///
/// Runs against the demo account of `Scripts-passy/vaultwarden/seed_demo.py` (set `TEST_RUNNER_PASSY_EMAIL` and
/// `TEST_RUNNER_PASSY_SERVER`) and is driven by `Scripts-passy/appstore_shots.sh`:
/// `test_signIn` once in English on a fresh install, then `test_storeScreens` once per language
/// (`TEST_RUNNER_PASSY_LANG=en|de`) on the same install.
final class ShotsAppStoreTests: PassYUITestCase {
    private var language: String { ProcessInfo.processInfo.environment["PASSY_LANG"] ?? "en" }
    private var locale: String { language == "de" ? "de_DE" : "en_US" }

    // MARK: Tests

    /// Logs in (English, fresh install) and prepares the demo layout: the vault stays unlocked ("Never"), so the later
    /// launches need no typing. On the home, four types stay cards, the others become folder rows, and "Types" and
    /// "Favorites" are collapsed, so cards and folders are both visible.
    func test_signIn() {
        let app = open(mode: "light")
        XCTAssertTrue(app.buttons["CategoryTile_totp"].waitForExistence(timeout: 60), "demo vault with codes")
        goTo(app, "Settings")
        app.buttons["AccountSecuritySettingsButton"].tap()
        let chooser = app.buttons["VaultTimeoutChooser"]
        for _ in 0 ..< 4 where !chooser.waitForExistence(timeout: 5) { app.swipeUp() }
        chooser.tap()
        let never = app.buttons["Never"].firstMatch
        for _ in 0 ..< 3 where !never.waitForExistence(timeout: 3) { app.swipeUp() }
        never.tap()
        let yes = app.alerts.buttons["Yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10), "never lock asks for confirmation")
        yes.tap()
        sleep(2)
        back(app)
        let customize = app.buttons["CustomizeSettingsButton"]
        XCTAssertTrue(customize.waitForExistence(timeout: 10))
        customize.tap()
        for id in ["secureNote", "driversLicense", "passport", "sshKey", "archive", "trash"] {
            set(app, "CustomizeTileToggle_\(id)", on: false)
        }
        set(app, "CustomizeSectionCollapsed_PassYTypes", on: true)
        set(app, "CustomizeSectionCollapsed_Favorites", on: true)
        sleep(2)
        app.terminate()
    }

    /// 01 vault home, 02 login with code, 03 verification codes, 04 generator, 05 filled cards, 06 dark.
    func test_storeScreens() {
        var app = open(mode: "light")
        settle(app)
        capture("01-vault")

        app.buttons["CategoryTile_login"].tap()
        let item = app.staticTexts["Pixel Studio"].firstMatch
        XCTAssertTrue(app.staticTexts["Acme Cloud"].firstMatch.waitForExistence(timeout: 15), "login list")
        for _ in 0 ..< 3 where !(item.exists && item.isHittable) { app.swipeUp(velocity: .slow) }
        item.tap()
        XCTAssertTrue(app.descendants(matching: .any)["LoginUsernameEntry"].waitForExistence(timeout: 15), "item view")
        sleep(3)
        captureWithCode("02-login")
        app.terminate()

        app = open(mode: "light")
        settle(app)
        app.buttons["CategoryTile_totp"].tap()
        XCTAssertTrue(app.staticTexts["Blue Harbor Bank"].firstMatch.waitForExistence(timeout: 15), "codes list")
        sleep(3)
        captureWithCode("03-codes")
        app.terminate()

        app = open(mode: "light")
        settle(app)
        openMenuEntry(app, id: "ProfileMenuGeneratorButton", labels: ["Generator"])
        XCTAssertTrue(app.staticTexts["GeneratedPasswordLabel"].waitForExistence(timeout: 15), "generator")
        sleep(3)
        capture("04-generator")
        app.terminate()

        app = open(mode: "light")
        settle(app)
        setCardColors(app, language == "de" ? "Vollfarbig" : "Filled")
        app.terminate()
        app = open(mode: "light")
        settle(app)
        capture("05-colors")
        setCardColors(app, language == "de" ? "Bunt" : "Colorful")
        app.terminate()

        app = open(mode: "dark")
        settle(app)
        capture("06-dark")
        app.terminate()
    }

    /// Turns on Settings > Other > Connect to Watch and keeps the app in the foreground for the paired watch.
    func test_connectWatch() {
        let app = open(mode: "light")
        goTo(app, "Settings")
        app.buttons["OtherSettingsButton"].tap()
        let toggle = app.switches.matching(NSPredicate(format: "label CONTAINS 'Connect to Watch'")).firstMatch
        for _ in 0 ..< 4 where !toggle.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(toggle.exists, "Connect to Watch switch\n\(app.debugDescription)")
        for _ in 0 ..< 3 where toggle.value as? String != "1" {
            if toggle.frame.maxY > app.frame.maxY - 140 { app.swipeUp(velocity: .slow) }
            sleep(1)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            _ = waitUntil(10) { toggle.value as? String == "1" }
        }
        XCTAssertEqual(toggle.value as? String, "1", "Connect to Watch is on")
        capture("check-connect-watch")
        sleep(UInt32(ProcessInfo.processInfo.environment["PASSY_HOLD_SECONDS"].flatMap(Int.init) ?? 5))
    }

    /// Settings, About, Licenses, AutoFill and its set-up steps (checked by eye).
    func test_checkSettingsScreens() {
        let app = open(mode: "light")
        goTo(app, "Settings")
        sleep(2)
        capture("check-settings")
        app.swipeUp()
        sleep(1)
        capture("check-settings-bottom")
        app.buttons["AboutSettingsButton"].tap()
        XCTAssertTrue(app.buttons["LicensesButton"].waitForExistence(timeout: 10))
        sleep(1)
        capture("check-about")
        app.buttons["LicensesButton"].tap()
        XCTAssertTrue(app.buttons["LicensesGPLButton"].waitForExistence(timeout: 10))
        sleep(1)
        capture("check-licenses")
        app.swipeUp()
        sleep(1)
        capture("check-licenses-bottom")
        app.swipeDown()
        sleep(1)
        app.buttons["LicensesGPLButton"].tap()
        sleep(2)
        capture("check-licenses-gpl")
        back(app)
        let crates = app.buttons["LicensesCratesButton"]
        for _ in 0 ..< 6 where !(crates.exists && crates.isHittable) { app.swipeUp() }
        if crates.exists {
            crates.tap()
            sleep(2)
            capture("check-licenses-crates")
            back(app)
        }
        back(app)
        back(app)
        let autofill = app.buttons["AutofillSettingsButton"]
        for _ in 0 ..< 4 where !(autofill.exists && autofill.isHittable) { app.swipeDown() }
        autofill.tap()
        sleep(2)
        capture("check-autofill")
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Password AutoFill'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Password AutoFill row\n\(app.debugDescription)")
        row.tap()
        sleep(2)
        capture("check-autofill-steps")
        app.swipeUp()
        sleep(1)
        capture("check-autofill-steps-bottom")
        app.terminate()
    }

    /// Shares the first photo of the simulator's library to Pass-Y: the share extension has to show its screen.
    func test_checkShareExtension() {
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        photos.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        photos.launch()
        for _ in 0 ..< 3 {
            let next = photos.buttons.matching(NSPredicate(format: "label IN {'Continue', 'Not Now'}")).firstMatch
            if next.waitForExistence(timeout: 4) { next.tap() }
        }
        sleep(2)
        let image = photos.images.matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info' OR label BEGINSWITH 'Photo'"))
            .allElementsBoundByIndex.last(where: { $0.isHittable })
        XCTAssertNotNil(image, "a photo in the library\n\(photos.debugDescription)")
        image?.tap()
        let share = photos.buttons.matching(NSPredicate(format: "label == 'Share'")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10), "share button\n\(photos.debugDescription)")
        share.tap()
        sleep(3)
        capture("check-share-sheet")
        let target = photos.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Pass-Y'")).firstMatch
        if !target.waitForExistence(timeout: 5) {
            // Not in the first row of share targets: open "More".
            let more = photos.cells.matching(NSPredicate(format: "label == 'More'")).firstMatch
            for _ in 0 ..< 4 where !(more.exists && more.isHittable) {
                photos.cells.matching(NSPredicate(format: "label IN {'Messages', 'Mail', 'Reminders', 'AirDrop'}"))
                    .firstMatch.swipeLeft()
            }
            if more.exists { more.tap(); sleep(2); capture("check-share-more") }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Pass-Y in the share sheet\n\(photos.debugDescription)")
        target.tap()
        sleep(8)
        capture("check-share-extension")
        let unlock = photos.secureTextFields["MasterPasswordEntry"]
        if unlock.waitForExistence(timeout: 5) {
            unlock.replaceText(TestAccount.password)
            photos.buttons["UnlockVaultButton"].tap()
            sleep(8)
            capture("check-share-extension-unlocked")
        }
        print("SHARE-TREE\n\(photos.debugDescription)")
    }

    // MARK: Helpers

    /// A fresh launch in the language of this run, unlocked.
    private func open(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
            "-passyForceInterfaceStyle", mode,
        ]
        app.launch()
        ensureUnlockedVault(app)
        return app
    }

    /// Waits until the vault home is complete (no toast, no spinner).
    private func settle(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["CategoryTile_totp"].waitForExistence(timeout: 30), "vault home")
        _ = waitUntil(20) { !app.activityIndicators.firstMatch.exists }
        sleep(5)
    }

    /// Several shots early in a code period (full ring, no red countdown), taken between two ticks of the countdown;
    /// the first is the store image, the others are spares in case a digit was captured mid-animation.
    private func captureWithCode(_ name: String) {
        while !(2 ... 6).contains(Int(Date().timeIntervalSince1970) % 30) { usleep(300_000) }
        for index in 0 ..< 4 {
            let fraction = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
            usleep(useconds_t((1.55 + Double(index) * 0.1 - fraction) * 1_000_000))
            capture(index == 0 ? name : "spare-\(name)-\(index)")
        }
    }

    /// Switches a Customize toggle, scrolling to it first. The list can reorder and move the switch off screen after
    /// the tap, so it is looked up again.
    private func set(_ app: XCUIApplication, _ identifier: String, on: Bool) {
        let toggle = app.switches[identifier].firstMatch
        func isClear() -> Bool {
            // "Hittable" is not enough: a switch under the floating bottom bar takes the tap to the search field.
            toggle.exists && toggle.isHittable && toggle.frame.minY > 130 && toggle.frame.maxY < app.frame.maxY - 140
        }
        func reveal() {
            for _ in 0 ..< 10 where !isClear() { app.swipeUp(velocity: .slow) }
            for _ in 0 ..< 14 where !isClear() { app.swipeDown(velocity: .slow) }
            XCTAssertTrue(isClear(), "toggle \(identifier)")
        }
        reveal()
        let wanted = on ? "1" : "0"
        // A tap while the list still scrolls is sometimes lost: look again and repeat.
        for _ in 0 ..< 3 where toggle.value as? String != wanted {
            sleep(1)
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            sleep(2)
            reveal()
        }
        XCTAssertEqual(toggle.value as? String, wanted, identifier)
    }

    /// Settings > Customize > card colours.
    private func setCardColors(_ app: XCUIApplication, _ label: String) {
        openMenuEntry(app, id: "ProfileMenuSettingsButton", labels: ["Settings", "Einstellungen"])
        let customize = app.buttons["CustomizeSettingsButton"]
        XCTAssertTrue(customize.waitForExistence(timeout: 15), "settings")
        customize.tap()
        let picker = app.descendants(matching: .any)["CustomizeCardColorsPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "card colours")
        picker.tap()
        let option = app.buttons[label].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10), "option \(label)\n\(app.debugDescription)")
        option.tap()
        sleep(2)
    }

    private func openMenuEntry(_ app: XCUIApplication, id: String, labels: [String]) {
        XCTAssertTrue(app.buttons["CurrentActiveAccount"].waitForExistence(timeout: 10))
        app.buttons["CurrentActiveAccount"].tap()
        let entry = app.descendants(matching: .any).matching(NSPredicate(
            format: "(identifier == %@ OR label IN %@) AND (elementType == %d OR elementType == %d)",
            id, labels, XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.menuItem.rawValue,
        )).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "menu entry \(labels)\n\(app.debugDescription)")
        entry.tap()
    }

    /// A whole-screen shot, so the (overridden) status bar is part of it.
    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "appstore-\(language)-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
