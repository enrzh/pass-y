import XCTest

/// The Liquid Glass copy toast (`ToastView`) in the running app, light and dark: copying the password in the item view
/// and from a list row's context menu shows a legible "copied" toast that sits above the bottom bar (never on it) and
/// goes away by itself after about 3 s. Runs on the phone (full-phone step) and, by name, on the iPad.
final class CopyToastTests: PassYUITestCase {
    func test_copyPasswordToastAboveBarAndDismisses() {
        addTeardownBlock { setPassYAppearance(.light) }
        for mode in passYModes() {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let app = launchApp()
            openLoginList(app)
            let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "phone"
            let row = app.buttons["VaultListItemRowButton"].firstMatch

            // 1. Item view (opened from the Logins list, no keyboard): long press the password row, Copy.
            row.tap()
            let password = app.descendants(matching: .any)["LoginPasswordEntry"]
            XCTAssertTrue(password.waitForExistence(timeout: 10), "item view with a password row")
            password.press(forDuration: 1.2)
            let copy = app.buttons["Copy"].exists ? app.buttons["Copy"] : app.menuItems["Copy"]
            XCTAssertTrue(copy.waitForExistence(timeout: 5), "context menu offers Copy")
            var tapped = Date()
            copy.tap()
            checkToast(app, name: "\(mode)-\(device)-item-view", tapped: tapped)

            // 2. The Logins list with the bottom bar: the row's context menu, Copy password.
            closeSheet(app)
            XCTAssertTrue(row.waitForExistence(timeout: 10), "back on the Logins list")
            row.press(forDuration: 1.2)
            let copyPassword = app.buttons["Copy password"].exists ? app.buttons["Copy password"] : app.menuItems["Copy password"]
            XCTAssertTrue(copyPassword.waitForExistence(timeout: 5), "row menu offers Copy password")
            tapped = Date()
            copyPassword.tap()
            let toast = checkToast(app, name: "\(mode)-\(device)-list", tapped: tapped) { toast in
                let bar = app.searchFields.firstMatch
                XCTAssertTrue(bar.exists, "the bottom bar's search field is on the list page")
                XCTAssertLessThanOrEqual(toast.maxY, bar.frame.minY, "\(mode): the toast \(toast) sits above the bar \(bar.frame)")
                // Just above it (12 pt in `ToastView`), not floating over the list (the bar's height was added twice).
                XCTAssertLessThanOrEqual(bar.frame.minY - toast.maxY, 30, "\(mode): the toast \(toast) is close to the bar \(bar.frame)")
            }
            XCTAssertNotNil(toast)
        }
    }

    /// Waits for the toast, attaches a screenshot, checks it is on screen with a "copied" text, runs `extra` with its
    /// frame, then waits until it is gone and checks the time from the copy tap to its disappearance (3 s in
    /// `ToastView` plus the transitions; the upper bound leaves room for the XCUITest query latency).
    @discardableResult
    private func checkToast(
        _ app: XCUIApplication,
        name: String,
        tapped: Date,
        extra: ((CGRect) -> Void)? = nil,
    ) -> CGRect? {
        let toast = app.descendants(matching: .any)["ToastElement"].firstMatch
        guard toast.waitForExistence(timeout: 5) else {
            XCTFail("\(name): no toast")
            return nil
        }
        // Frame and text first, the screenshot after (it can take a second under load; the toast lives 3 s).
        let frame = toast.frame
        let label = toast.label
        attach(app, "toast-\(name)")
        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(frame), "\(name): toast \(frame) inside the window \(screen)")
        XCTAssertTrue(label.localizedCaseInsensitiveContains("copied"), "\(name): toast text is '\(label)'")
        extra?(frame)
        XCTAssertTrue(waitForDisappearance(of: toast, timeout: 10), "\(name): the toast dismisses by itself")
        let life = Date().timeIntervalSince(tapped)
        print("PASSY-TOAST \(name) frame=\(frame) screen=\(screen) tapToGone=\(String(format: "%.1f", life))s")
        XCTAssertGreaterThan(life, 2.8, "\(name): the toast stays about 3 s")
        XCTAssertLessThan(life, 7, "\(name): the toast goes away after about 3 s")
        return frame
    }
}
