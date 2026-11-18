import SwiftUI
import XCTest

@testable import BitwardenShared

/// ui-r7: the avatar darkens its account color just enough for white initials to reach the contrast audit's 4.5:1.
class PassYAvatarContrastTests: BitwardenTestCase {
    private func ratio(of color: UIColor, darkening: Double) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> Double {
            let v = Double(value) * (1 - darkening)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return 1.05 / (luminance + 0.05)
    }

    /// Bright account colors need a stronger overlay, dark ones none; the result always reaches 4.5:1.
    func test_darkening_reachesContrastForAnyColor() {
        let colors: [UIColor] = [.systemYellow, .systemOrange, .systemGreen, .systemTeal, .systemBlue, .systemPink,
                                 .white, .black, UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1)]
        for color in colors {
            let darkening = PassYAvatarMenu.darkening(for: Color(color))
            XCTAssertGreaterThanOrEqual(darkening, 0)
            XCTAssertLessThanOrEqual(darkening, 0.6)
            if darkening < 0.6 {
                XCTAssertGreaterThanOrEqual(ratio(of: color, darkening: darkening), 4.5, "\(color)")
            }
        }
        XCTAssertEqual(PassYAvatarMenu.darkening(for: Color(.black)), 0)
        XCTAssertGreaterThan(PassYAvatarMenu.darkening(for: Color(.systemYellow)), PassYAvatarMenu.darkening(for: Color(.systemBlue)))
    }

    /// No color falls back to a fixed overlay.
    func test_darkening_nilColor() {
        XCTAssertEqual(PassYAvatarMenu.darkening(for: nil), 0.3)
    }
}
