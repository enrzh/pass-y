import XCTest

/// The password generator.
final class GeneratorTests: PassYUITestCase {
    /// Formerly `PassYFlowTests.test05_generator`.
    func test_generatorRegenerates() {
        let app = launchApp()
        ensureUnlockedVault(app)
        goTo(app, "Generator")
        let label = app.staticTexts["GeneratedPasswordLabel"]
        XCTAssertTrue(waitFor(label), "generated password is shown")
        let first = label.label
        XCTAssertGreaterThanOrEqual(first.count, 8)
        attach(app, "05-generator")
        let regen = app.buttons["RegeneratePasswordButton"].exists ? app.buttons["RegeneratePasswordButton"] : app.buttons["Generate password"]
        if regen.exists {
            regen.tap(); sleep(1)
            XCTAssertNotEqual(app.staticTexts["GeneratedPasswordLabel"].label, first, "regenerate changes password")
        }
        goTo(app, "My vault")
    }
}
