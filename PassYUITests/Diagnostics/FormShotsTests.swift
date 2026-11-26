import XCTest

/// Before/after screenshots of the form pages for the PassYDesign forms work: item view (GitHub, scrolled), item edit,
/// the add form of every item type, Send add (text, file), the folders page and the add-folder form, the generator
/// (password, passphrase, username) and the password history: light and dark, plus Accessibility XXXL for the item
/// view, the item edit and the generator. Runs on the phone or the iPad simulator, never gating (run by name;
/// `STEP_ENV="PASSY_DESIGN_TAG=<set>"` names the set). A missing element skips that screen instead of failing the set.
final class FormShotsTests: PassYUITestCase {
    private var set: String { ProcessInfo.processInfo.environment["PASSY_DESIGN_TAG"] ?? "forms" }

    func test_formPages() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            guard app.buttons["CategoryTile_login"].waitForExistence(timeout: 15) else { continue }
            itemPages(app, mode)
            addForms(app, mode)
            sendPages(app, mode)
            folderPages(app, mode)
            generatorPages(app, mode)
            app.terminate()
        }
        setPassYAppearance(.light)
        let app = launchApp(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        ensureUnlockedVault(app)
        itemPages(app, "light-ax")
        generatorPages(app, "light-ax")
        app.terminate()
    }

    // MARK: Pages

    private func itemPages(_ app: XCUIApplication, _ mode: String) {
        openGitHubViaSearch(app)
        capture(app, mode, 1, "item-view")
        app.swipeUp(); sleep(1)
        capture(app, mode, 2, "item-view-bottom")
        app.swipeUp(); sleep(1)
        capture(app, mode, 3, "item-view-end")
        let edit = app.buttons["EditItemButton"]
        if tapIfPresent(edit) {
            sleep(2)
            capture(app, mode, 4, "item-edit")
            app.swipeUp(); sleep(1)
            capture(app, mode, 5, "item-edit-bottom")
            let additional = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Additional options'")).firstMatch
            if additional.exists, additional.isHittable { additional.tap(); sleep(1) }
            app.swipeUp(); sleep(1)
            capture(app, mode, 6, "item-edit-end")
            closeSheet(app)
        }
        closeSheet(app)
        let cancel = app.buttons["VaultSearchCancel"]
        if cancel.exists { cancel.tap() } else if app.buttons["Cancel"].exists { app.buttons["Cancel"].firstMatch.tap() }
        sleep(1)
    }

    private func addForms(_ app: XCUIApplication, _ mode: String) {
        var n = 10
        for type in ["Login", "Card", "Identity", "Secure note", "SSH key", "Bank account", "Passport", "Driver"] {
            guard openAdd(app, type) else { continue }
            let ok = app.alerts.buttons["OK"]
            if ok.waitForExistence(timeout: 1) { ok.tap() }
            app.dismissNewLoginCard()
            capture(app, mode, n, "add-\(type.lowercased().replacingOccurrences(of: " ", with: "-"))"); n += 1
            if ["Login", "Card", "Identity"].contains(type) {
                app.swipeUp(); sleep(1)
                capture(app, mode, n, "add-\(type.lowercased())-bottom"); n += 1
            }
            closeSheet(app)
        }
    }

    private func sendPages(_ app: XCUIApplication, _ mode: String) {
        goTo(app, "Send"); sleep(2)
        for (n, type) in [(30, "Text"), (32, "File")] {
            let add = app.buttons["AddItemFloatingActionButton"]
            guard add.waitForExistence(timeout: 8) else { return }
            add.tap(); sleep(1)
            let menu = app.menuItems[type]
            let button = app.buttons.matching(NSPredicate(format: "label == %@", type)).firstMatch
            if menu.waitForExistence(timeout: 3) { menu.tap() } else if button.exists { button.tap() } else { app.tap(); continue }
            sleep(2)
            capture(app, mode, n, "send-add-\(type.lowercased())")
            app.swipeUp(); sleep(1)
            let options = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Additional options'")).firstMatch
            if options.exists, options.isHittable { options.tap(); sleep(1); app.swipeUp(); sleep(1) }
            capture(app, mode, n + 1, "send-add-\(type.lowercased())-bottom")
            closeSheet(app)
        }
        let row = app.buttons["SendCell"].firstMatch.exists ? app.buttons["SendCell"].firstMatch
            : app.buttons["VaultListItemRowButton"].firstMatch
        if tapIfPresent(row) {
            sleep(2)
            capture(app, mode, 34, "send-view")
            closeSheet(app)
        }
    }

    private func folderPages(_ app: XCUIApplication, _ mode: String) {
        goTo(app, "Settings")
        guard tapIfPresent(app.buttons["VaultSettingsButton"]) else { return }
        sleep(1)
        guard tapIfPresent(app.buttons["FoldersLabel"]) else { return }
        sleep(2)
        capture(app, mode, 40, "folders")
        if tapIfPresent(app.buttons["AddItemButton"]) {
            sleep(2)
            capture(app, mode, 41, "folder-add")
            closeSheet(app)
        }
        if tapIfPresent(app.buttons["FolderCell"].firstMatch) {
            sleep(2)
            capture(app, mode, 42, "folder-edit")
            closeSheet(app)
        }
        back(app); back(app)
    }

    private func generatorPages(_ app: XCUIApplication, _ mode: String) {
        goTo(app, "Generator"); sleep(2)
        capture(app, mode, 50, "generator-password")
        app.swipeUp(); sleep(1)
        capture(app, mode, 51, "generator-password-bottom")
        app.swipeDown(); app.swipeDown(); sleep(1)
        for (n, label) in [(52, "Passphrase"), (53, "Username")] {
            let segment = app.buttons[label].firstMatch
            if tapIfPresent(segment) { sleep(2); capture(app, mode, n, "generator-\(label.lowercased())") }
        }
        let password = app.buttons["Password"].firstMatch
        if password.exists, password.isHittable { password.tap(); sleep(1) }
        let history = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'history'")).firstMatch
        let options = app.buttons["HeaderBarOptionsButton"].firstMatch
        if !history.exists, options.exists, options.isHittable { options.tap(); sleep(1) }
        if tapIfPresent(history) {
            sleep(2)
            capture(app, mode, 54, "password-history")
            closeSheet(app)
        }
        goTo(app, "My vault")
    }

    // MARK: Helpers

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
