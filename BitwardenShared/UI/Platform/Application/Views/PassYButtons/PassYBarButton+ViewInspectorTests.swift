// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenResources
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

/// The shared bottom bar button: identifiers and labels the UI tests use, a 44 pt target, a synchronous action.
class PassYBarButtonViewInspectorTests: BitwardenTestCase {
    /// The Vault button keeps its identifier and label, and the tap runs the action right away (no task hop).
    @MainActor
    func test_vault_identifierLabelAndSynchronousAction() throws {
        var taps = 0
        let subject = PassYBarButton.vault { taps += 1 }
        let button = try subject.inspect().find(ViewType.Button.self)
        XCTAssertEqual(try button.accessibilityIdentifier(), "BottomBarVaultButton")
        XCTAssertEqual(try button.accessibilityLabel().string(), Localizations.myVault)
        try button.tap()
        XCTAssertEqual(taps, 1, "the action ran synchronously in the tap")
    }

    /// The search cancel keeps its identifier and label, and its symbol fills a 44 x 44 pt target.
    @MainActor
    func test_searchCancel_identifierLabelAndTarget() throws {
        var taps = 0
        let subject = PassYBarButton.searchCancel { taps += 1 }
        let button = try subject.inspect().find(ViewType.Button.self)
        XCTAssertEqual(try button.accessibilityIdentifier(), "VaultSearchCancel")
        XCTAssertEqual(try button.accessibilityLabel().string(), Localizations.cancel)
        let image = try button.labelView().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "xmark")
        let frame = try image.fixedFrame()
        XCTAssertEqual(frame.width, PassYButtonMetrics.minTarget)
        XCTAssertEqual(frame.height, PassYButtonMetrics.minTarget)
        try button.tap()
        XCTAssertEqual(taps, 1)
    }
}
