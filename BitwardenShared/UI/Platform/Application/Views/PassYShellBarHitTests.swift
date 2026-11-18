import BitwardenKit
import SwiftUI
import XCTest

@testable import BitwardenShared

// MARK: - PassYShellBarHitTests

/// The persistent bottom bar sits over the page. Everything of it that is not a control must let touches through to
/// the list below (ui-r8: part of the "needs two taps" investigation), and the controls must still be hit.
@MainActor
final class PassYShellBarHitTests: BitwardenTestCase {
    // MARK: Properties

    var model: PassYShellModel!
    var host: UIHostingController<PassYShellBar>!
    var container: PassYBarContainerView!
    var hostWindow: UIWindow!

    // MARK: Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        model = PassYShellModel()
        host = UIHostingController(rootView: PassYShellBar(model: model))
        host.view.backgroundColor = .clear
        let height = PassYShellBar.barHeight + PassYShellBar.fadeHeight
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            hostWindow = UIWindow(windowScene: scene)
            hostWindow.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        } else {
            hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        hostWindow.rootViewController = UIViewController()
        hostWindow.makeKeyAndVisible()
        hostWindow.rootViewController?.addChild(host)
        container = PassYBarContainerView(hostView: host.view, model: model)
        container.frame = CGRect(x: 0, y: 844 - height - 34, width: 390, height: height)
        hostWindow.rootViewController?.view.addSubview(container)
        host.didMove(toParent: hostWindow.rootViewController)
        settle()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        hostWindow.isHidden = true
        hostWindow = nil
        host = nil
        model = nil
    }

    // MARK: Helpers

    func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hostWindow.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    /// The view that receives a touch at `point` (in the bar host's coordinates), `nil` when the touch passes through.
    func hit(_ point: CGPoint) -> UIView? {
        let inWindow = container.convert(point, to: hostWindow)
        return hostWindow.hitTest(inWindow, with: nil)
    }

    /// Whether the touch lands on the bar host (or inside it) rather than the page below.
    func isCaptured(_ point: CGPoint) -> Bool {
        guard let view = hit(point) else { return false }
        return view === host.view || view.isDescendant(of: container)
    }

    // MARK: Tests

    /// The strip above the controls and the gaps next to them belong to the page below.
    func test_transparentAreas_passTouchesThrough() {
        let top = PassYShellBar.fadeHeight > 0 ? PassYShellBar.fadeHeight / 2 : 2
        print("PERF hit fadeHeight=\(PassYShellBar.fadeHeight) top=\(isCaptured(CGPoint(x: 195, y: top))) "
            + "leftMargin=\(isCaptured(CGPoint(x: 4, y: PassYShellBar.fadeHeight + 30))) "
            + "hostHeight=\(container.frame.height)")
        XCTAssertFalse(isCaptured(CGPoint(x: 195, y: top)), "strip above the bar controls passes touches through")
        XCTAssertFalse(isCaptured(CGPoint(x: 4, y: PassYShellBar.fadeHeight + 30)), "left margin passes touches through")
    }

    /// The search field is hit where it is drawn.
    func test_searchField_isHit() {
        XCTAssertTrue(isCaptured(CGPoint(x: 120, y: PassYShellBar.fadeHeight + PassYShellBar.barHeight / 2)))
    }

    /// The bar has no backdrop band: its host is exactly as tall as the controls plus their padding.
    func test_noBackdropStrip() {
        XCTAssertEqual(PassYShellBar.fadeHeight, 0, "no fade strip above the bar (ui-r8: no shadow behind the bar)")
    }

    /// Off the vault home the Vault button is left of the search field and is hit; the gap between them is not.
    func test_vaultButton_isHit_andGapPassesThrough() {
        model.isAtVaultHome = false
        settle()
        let y = PassYShellBar.fadeHeight + PassYShellBar.barHeight / 2
        XCTAssertTrue(isCaptured(CGPoint(x: 38, y: y)), "Vault button is hit")
        XCTAssertTrue(isCaptured(CGPoint(x: 200, y: y)), "search field is hit")
    }

    /// On the vault home there is no button: the space is the search field.
    func test_vaultHome_hasNoVaultButton() {
        model.isAtVaultHome = true
        settle()
        let y = PassYShellBar.fadeHeight + PassYShellBar.barHeight / 2
        XCTAssertTrue(isCaptured(CGPoint(x: 40, y: y)), "search field starts at the left margin")
    }
}
