import XCTest

/// Dark mode: the main screens render dark (pixel check in `attach`).
final class AppearanceTests: PassYUITestCase {
    /// Formerly `PassYZAppearanceTests.test_darkMode`.
    func test_darkModeWalk() {
        setPassYAppearance(.dark)
        defer { setPassYAppearance(.light) }
        walkScreens(launchApp(), prefix: "dark")
    }
}
