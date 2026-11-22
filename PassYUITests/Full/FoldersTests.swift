import XCTest

/// Folders: native list, add from the toolbar, single tap opens, empty folder page has no backdrop behind the bar.
final class FoldersTests: PassYUITestCase {
    /// Creates folders through the UI, then checks the native folders list and that the last row can be scrolled clear of the add button.
    /// Formerly `PassYFlowTests.test17_foldersListLastRowClearOfAddButton`.
    func test_foldersListLastRowClearOfBar() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        app.buttons["VaultSettingsButton"].tap(); sleep(1)
        app.buttons["FoldersLabel"].tap(); sleep(2)
        let add = app.buttons["AddItemButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "folders screen has the add button in the toolbar")
        XCTAssertFalse(app.buttons["AddItemFloatingActionButton"].exists, "no floating add button on the folders list")
        let existing = app.buttons.matching(identifier: "FolderCell").count
        for i in min(existing, 12) ..< 12 {
            add.tap()
            let field = app.textFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10), "folder name field")
            field.tap(); field.typeText("PassY Folder \(String(format: "%02d", i))")
            app.buttons["SaveButton"].firstMatch.tap()
            XCTAssertTrue(add.waitForExistence(timeout: 10), "back on the folders list")
            sleep(1)
        }
        attach(app, "17-folders-filled")
        for _ in 0 ..< 6 { app.swipeUp() }
        sleep(1)
        attach(app, "17-folders-scrolled-to-end")
        let cells = app.buttons.matching(identifier: "FolderCell")
        let last = cells.element(boundBy: cells.count - 1)
        XCTAssertTrue(last.exists && last.isHittable, "the last folder row is reachable")
        let bar = app.searchFields.firstMatch
        XCTAssertLessThanOrEqual(last.frame.maxY, bar.frame.minY + 1,
                                 "last row (\(last.frame)) sits above the bottom search bar (\(bar.frame))")
    }

    /// Vault settings are a native list and the folders page adds folders from the toolbar.
    /// Formerly `PassYFlowTests.test24_settingsFoldersNative`.
    func test_settingsFoldersNative() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Settings")
        app.buttons["VaultSettingsButton"].tap(); sleep(1)
        XCTAssertTrue(app.buttons["FoldersLabel"].exists && app.buttons["ExportVaultLabel"].exists, "vault settings rows")
        XCTAssertFalse(app.buttons["ImportItemsLinkItemView"].exists, "ui-r9: no web vault import row")
        app.buttons["FoldersLabel"].tap(); sleep(1)
        let add = app.buttons["AddItemButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "folders: add in the toolbar")
        XCTAssertFalse(app.buttons["AddItemFloatingActionButton"].exists, "no leftover blue plus next to the bar")
        add.tap()
        let name = app.textFields["FolderNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "native name field in a Form")
        attach(app, "24-add-folder")
    }

    /// One tap on a folder row (blank part) pushes the folder page within one second.
    /// Formerly `PassYUiR8Tests.test02_singleTapOpensFolder`.
    func test_singleTapOpensFolder() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let folderName = "PassY Tap Folder"
        if !scrollToFolder(app, folderName) {
            createFolder(app, folderName)
            XCTAssertTrue(scrollToFolder(app, folderName), "folder row exists")
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", folderName)).firstMatch
        XCTAssertTrue(row.exists)
        tapBlank(row)
        XCTAssertTrue(appears(app.navigationBars.staticTexts[folderName]), "one tap on the folder row opens the folder within 1 s")
        shot(app, 2, "folder-after-one-tap")
        // Back works with the system back button and the Vault button returns to the home.
        XCTAssertTrue(vaultButton(app).exists, "pushed page shows the Vault button")
        vaultButton(app).tap()
        // The home keeps its scroll position (it was scrolled to the folder): scroll up to see the tiles again.
        for _ in 0 ..< 8 where !app.buttons["CategoryTile_login"].exists { app.swipeDown() }
        XCTAssertTrue(waitFor(app.buttons["CategoryTile_login"]), "Vault button returns to the vault home")
    }

    /// Nothing is drawn behind the bar. On an empty folder page (created here, so the content does not depend on the state
    /// left by earlier tests) the pixels 6, 20 and 60 pt above the bar, left of the controls, have the page color: the pixel
    /// at the very bottom of the screen (below the bar). A material or gradient backdrop would make them differ.
    /// Formerly `PassYUiR8Tests.test05_noBackdropBehindBar`.
    func test_emptyFolderNoBackdropBehindBar() {
        let app = launchApp()
        ensureUnlockedVault(app)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        shot(app, 30, "vault-bar-no-shadow")
        let folderName = "PassY Pixel Folder"
        if !scrollToFolder(app, folderName) {
            createFolder(app, folderName)
            XCTAssertTrue(scrollToFolder(app, folderName), "empty folder row exists")
        }
        app.buttons.matching(NSPredicate(format: "identifier == 'VaultListItemRowButton' AND label CONTAINS %@", folderName)).firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars.staticTexts[folderName].waitForExistence(timeout: 5), "empty folder page")
        sleep(2)
        let screen = app.windows.firstMatch.frame
        let image = app.screenshot().image
        guard let cg = image.cgImage else { return XCTFail("screenshot") }
        let scale = CGFloat(cg.width) / screen.width
        func pixel(_ x: CGFloat, _ y: CGFloat) -> [UInt8] {
            guard let crop = cg.cropping(to: CGRect(x: x * scale, y: y * scale, width: 2, height: 2)),
                  let data = crop.dataProvider?.data as Data? else { return [] }
            return Array(data.prefix(3))
        }
        let barTop = search.frame.minY
        let reference = pixel(6, screen.height - 3)
        XCTAssertFalse(reference.isEmpty)
        for offset: CGFloat in [6, 20, 60] {
            // ui-r9: the fade is the page color itself (a gradient of the same color), so the pixel may differ by blending
            // rounding only; a material or a different color would differ by far more than 3 per channel.
            let sample = pixel(6, barTop - offset)
            XCTAssertEqual(sample.count, reference.count)
            for (a, b) in zip(sample, reference) {
                XCTAssertLessThanOrEqual(abs(Int(a) - Int(b)), 3, "pixel \(offset) pt above the bar is the page color (no backdrop): \(sample) vs \(reference)")
            }
        }
        shot(app, 31, "empty-folder-bar-no-shadow")
    }
}
