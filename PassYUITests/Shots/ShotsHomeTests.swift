import XCTest

/// Screenshots of the vault home tiles (light, dark, larger text). Never gating.
final class ShotsHomeTests: PassYUITestCase {
    /// Vault home (category tiles) in both appearances and with larger text.
    /// Formerly `PassYUiR4ShotsTests.test_tiles`.
    func test_tiles() {
        for (mode, size) in [("light", ""), ("dark", ""), ("light", "UICTContentSizeCategoryXL"), ("light", "UICTContentSizeCategoryAccessibilityL")] {
            setPassYAppearance(mode == "dark" ? .dark : .light)
            let extra = size.isEmpty ? [] : ["-UIPreferredContentSizeCategoryName", size]
            let app = launchApp(extraArguments: extra)
            ensureUnlockedVault(app)
            XCTAssertTrue(app.buttons["CategoryTile_totp"].waitForExistence(timeout: 10))
            shot(app, mode, size.isEmpty ? 70 : (size.contains("Accessibility") ? 72 : 71), size.isEmpty ? "tiles" : (size.contains("Accessibility") ? "tiles-accessibility" : "tiles-xl"))
            app.terminate()
        }
        setPassYAppearance(.light)
    }
}
