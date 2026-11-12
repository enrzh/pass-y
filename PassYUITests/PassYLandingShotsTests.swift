import XCTest

/// Captures the native Landing screen (needs a fresh install; no server required).
final class PassYLandingShotsTests: XCTestCase {
    func test_landingShot() {
        let tag = (try? String(contentsOfFile: "/tmp/passy_shot_tag", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "landing"
        let app = launchApp()
        XCTAssertTrue(waitFor(app.buttons["Log in"]))
        app.buttons["Log in"].tap()
        XCTAssertTrue(waitFor(app.textFields["ServerUrlEntry"]))
        attach(app, "\(tag)-server")
        app.buttons["CancelButton"].firstMatch.tap()
        XCTAssertTrue(waitFor(app.buttons["RegionSelectorDropdown"]))
        attach(app, "\(tag)-landing")
    }
}
