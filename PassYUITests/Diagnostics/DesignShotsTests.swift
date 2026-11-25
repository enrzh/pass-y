import XCTest

/// Before/after screenshots of the list pages for the PassYDesign work (vault home, Logins group, verification codes,
/// search results, Send, folders): light and dark, plus Accessibility XXXL for the Logins and codes pages. Runs on the
/// phone or the iPad simulator, never gating (run by name; `STEP_ENV="PASSY_DESIGN_TAG=<set>"` names the set). A
/// missing element skips that screen instead of failing the whole set.
final class DesignShotsTests: PassYUITestCase {
    private var set: String { ProcessInfo.processInfo.environment["PASSY_DESIGN_TAG"] ?? "shots" }

    func test_listPages() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            guard app.buttons["CategoryTile_login"].waitForExistence(timeout: 15) else { continue }
            capture(app, mode, 1, "home")
            app.swipeUp(); sleep(1)
            capture(app, mode, 2, "home-scrolled")
            app.swipeDown(); app.swipeDown(); sleep(1)
            if tapIfPresent(app.buttons["CategoryTile_login"]) {
                sleep(2); capture(app, mode, 3, "logins"); back(app)
            }
            if tapIfPresent(app.buttons["CategoryTile_totp"]) {
                sleep(3); capture(app, mode, 4, "codes"); back(app)
            }
            let search = app.searchFields.firstMatch
            // The search shot is skipped when the field does not take keyboard focus (seen once on the iPad).
            if tapIfPresent(search), (search.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
                || { sleep(2); return (search.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }() {
                sleep(1); typeSearch(app, "e"); sleep(2)
                capture(app, mode, 5, "search")
                let cancel = app.buttons["VaultSearchCancel"]
                if cancel.exists { cancel.tap() } else if app.buttons["Cancel"].exists { app.buttons["Cancel"].firstMatch.tap() }
                sleep(1)
            }
            goTo(app, "Send"); sleep(2)
            capture(app, mode, 6, "send")
            goTo(app, "Settings")
            if tapIfPresent(app.buttons["VaultSettingsButton"]) {
                sleep(1)
                if tapIfPresent(app.buttons["FoldersLabel"]) { sleep(2); capture(app, mode, 7, "folders") }
            }
            app.terminate()
        }
        setPassYAppearance(.light)
        let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        ensureUnlockedVault(app)
        for (n, id, name) in [(3, "CategoryTile_login", "logins"), (4, "CategoryTile_totp", "codes")] {
            let tile = app.buttons[id]
            guard tile.waitForExistence(timeout: 10) else { continue }
            for _ in 0 ..< 6 where !tile.isHittable { app.swipeUp() }
            guard tile.isHittable else { continue }
            tile.tap(); sleep(3)
            capture(app, "light-ax", n, name)
            app.swipeUp(); sleep(1)
            capture(app, "light-ax", n, "\(name)-scrolled")
            back(app)
        }
        app.terminate()
    }

    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 8), element.isHittable else { return false }
        element.tap()
        return true
    }

    private func capture(_ app: XCUIApplication, _ mode: String, _ n: Int, _ name: String) {
        sleep(1)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "phone"
        attachUnchecked(app, "\(set)-\(device)-\(mode)-\(String(format: "%02d", n))-\(name)")
    }
}
