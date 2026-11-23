import XCTest

/// Screenshots of Send. Never gating.
final class ShotsSendTests: PassYUITestCase {
    /// Send type list (tap a type row in the Send list).
    /// Formerly `PassYUiR4ShotsTests.test_sendTypeList`.
    func test_sendTypeList() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            goTo(app, "Send"); sleep(2)
            let row = app.staticTexts["Text"].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 8))
            row.tap(); sleep(2)
            print("R4DEBUG type list texts: \(app.staticTexts.allElementsBoundByIndex.prefix(6).map(\.label)) nav: \(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
            shot(app, mode, 21, "send-type-list")
            app.terminate()
        }
        setPassYAppearance(.light)
    }

    /// Send: type list, text add, file add, send view and edit; password history.
    /// Formerly `PassYUiR4ShotsTests.test_send`.
    func test_sendFormsAndPasswordHistory() {
        for mode in ["light", "dark"] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            ensureUnlockedVault(app)
            goTo(app, "Send"); sleep(2)
            shot(app, mode, 20, "send-list")
            for (i, kind) in ["Text", "File"].enumerated() {
                let add = app.buttons["AddItemFloatingActionButton"]
                guard add.waitForExistence(timeout: 8) else { break }
                add.tap(); sleep(1)
                let menuItem = app.menuItems[kind]
                let btn = app.buttons.matching(NSPredicate(format: "label == %@", kind)).firstMatch
                if !menuItem.waitForExistence(timeout: 2), !btn.exists { add.tap(); sleep(1) }
                if menuItem.waitForExistence(timeout: 3) { menuItem.tap() } else if btn.waitForExistence(timeout: 2) { btn.tap() } else {
                    print("R4DEBUG no \(kind) entry: \(app.menuItems.allElementsBoundByIndex.map(\.label)) \(app.buttons.allElementsBoundByIndex.prefix(12).map(\.label))"); app.tap(); continue }
                sleep(2)
                shot(app, mode, 22 + i, "send-add-\(kind.lowercased())")
                if i == 0 {
                    app.swipeUp(); sleep(1)
                    shot(app, mode, 24, "send-add-text-bottom")
                }
                cancelOrClose(app); discardIfAsked(app)
            }
            // Open the first existing send (view + edit) if any.
            let sendRow = app.descendants(matching: .any)["SendCell"].firstMatch
            if sendRow.waitForExistence(timeout: 3) {
                sendRow.tap(); sleep(2)
                shot(app, mode, 25, "send-view")
                let edit = app.buttons["Edit"].firstMatch
                if edit.exists { edit.tap(); sleep(2); shot(app, mode, 26, "send-edit"); cancelOrClose(app); discardIfAsked(app) }
                cancelOrClose(app)
            }
            // Password history from the generator.
            app.terminate()
            let app2 = launchApp(); ensureUnlockedVault(app2)
            goTo(app2, "Generator"); sleep(2)
            let options = app2.buttons["HeaderBarOptionsButton"].exists ? app2.buttons["HeaderBarOptionsButton"] : app2.buttons["Options"]
            if options.waitForExistence(timeout: 5) {
                options.tap(); sleep(1)
                let hist = app2.buttons["Password history"]
                if hist.waitForExistence(timeout: 3) {
                    hist.tap(); sleep(2)
                    shot(app2, mode, 30, "password-history")
                }
            }
            app2.terminate()
        }
        setPassYAppearance(.light)
    }
}
