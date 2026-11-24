import SwiftUI
import TestHelpers
import XCTest

@testable import BitwardenKit

class ToastTests: BitwardenTestCase {
    // MARK: Tests

    /// `symbol` maps copy confirmations to the copy symbol.
    func test_symbol_copied() {
        XCTAssertEqual(Toast(title: "Password copied").symbol, .copied)
        XCTAssertEqual(Toast(title: "Passwort kopiert").symbol, .copied)
    }

    /// `symbol` maps failures to the warning symbol.
    func test_symbol_failure() {
        XCTAssertEqual(Toast(title: "Sync failed").symbol, .failure)
        XCTAssertEqual(Toast(title: "Oops", subtitle: "An error occurred.").symbol, .failure)
    }

    /// `symbol` defaults to a checkmark.
    func test_symbol_default() {
        XCTAssertEqual(Toast(title: "Item saved").symbol, .success)
        XCTAssertEqual(Toast.Symbol.success.name, "checkmark.circle.fill")
    }

    /// The toast view renders as a hosted view with a non-empty size.
    @MainActor
    func test_toastView_hosted() {
        let host = UIHostingController(rootView: ToastView(toast: .constant(Toast(title: "Copied"))))
        let size = host.sizeThatFits(in: CGSize(width: 390, height: 800))
        XCTAssertGreaterThan(size.height, 30)
    }
}
