import BitwardenKit
import BitwardenKitMocks
import SwiftUI
import Testing
import UIKit

@testable import BitwardenShared

@MainActor
struct PassYShellControllerTests {
    // MARK: Types

    enum TestRoute: Int, Equatable, Hashable, TabRepresentable {
        case firstTab
        case secondTab
        case thirdTab

        static var firstTabImage = UIImage(systemName: "scribble.variable")
        static var firstTabSelectedImage = UIImage(systemName: "externaldrive.fill.badge.wifi")
        static var secondTabImage = UIImage(systemName: "doc.richtext.fill.ja")
        static var secondTabSelectedImage = UIImage(systemName: "lanyardcard.fill")
        static var thirdTabImage = UIImage(systemName: "figure.curling")
        static var thirdTabSelectedImage = UIImage(systemName: "medal.fill")

        var image: UIImage? {
            switch self {
            case .firstTab:
                Self.firstTabImage
            case .secondTab:
                Self.secondTabImage
            case .thirdTab:
                Self.thirdTabImage
            }
        }

        var selectedImage: UIImage? {
            switch self {
            case .firstTab:
                Self.firstTabSelectedImage
            case .secondTab:
                Self.secondTabSelectedImage
            case .thirdTab:
                Self.thirdTabSelectedImage
            }
        }

        var title: String {
            switch self {
            case .firstTab:
                "first"
            case .secondTab:
                "second"
            case .thirdTab:
                "third"
            }
        }
    }

    // MARK: Properties

    let subject: PassYShellController
    let window: UIWindow

    // MARK: Setup

    init() {
        window = UIWindow(frame: UIScreen.main.bounds)
        window.layer.speed = 100
        subject = PassYShellController(model: PassYShellModel())
        window.rootViewController = subject
        window.makeKeyAndVisible()
    }

    // MARK: Tests

    /// `isPresenting` returns true when a view is being presented on this navigator.
    @Test
    func isPresenting() {
        #expect(!subject.isPresenting)

        subject.present(UIViewController(), animated: false)
        #expect(subject.isPresenting)
    }

    /// `rootViewController` returns itself.
    @Test
    func rootViewController() {
        #expect(subject.rootViewController === subject)
    }

    /// `navigator(for:)` with `.firstTab` returns the navigator of that tab.
    @Test
    func navigatorFor_firstTab() {
        let navigator = MockRootNavigator()
        navigator.rootViewController = UIViewController()
        subject.setNavigators([TestRoute.firstTab: navigator])

        #expect(subject.navigator(for: TestRoute.firstTab) === navigator)
    }

    /// `navigator(for:)` with a `TabRoute` uses the stored dictionary and returns the correct
    /// navigator even when the Send tab is absent (non-contiguous indices).
    @Test
    func navigatorFor_tabRoute_sendHidden() {
        let vaultNavigator = MockRootNavigator()
        let generatorNavigator = MockRootNavigator()
        let settingsNavigator = MockRootNavigator()
        vaultNavigator.rootViewController = UIViewController()
        generatorNavigator.rootViewController = UIViewController()
        settingsNavigator.rootViewController = UIViewController()

        let tabs: [TabRoute: MockRootNavigator] = [
            .vault(.list): vaultNavigator,
            .generator(.generator()): generatorNavigator,
            .settings(.settings(.tab)): settingsNavigator,
        ]
        subject.setNavigators(tabs)

        #expect(subject.navigator(for: TabRoute.generator(.generator())) === generatorNavigator)
        #expect(subject.navigator(for: TabRoute.settings(.settings(.tab))) === settingsNavigator)
        #expect(subject.navigator(for: TabRoute.send) == nil)
    }

    /// `navigator(for:)` matches by tab case and ignores associated values, returning the
    /// correct navigator even when the route carries a non-canonical associated value.
    @Test
    func navigatorFor_tabRoute_nonCanonicalAssociatedValue() {
        let vaultNavigator = MockRootNavigator()
        let generatorNavigator = MockRootNavigator()
        let settingsNavigator = MockRootNavigator()
        vaultNavigator.rootViewController = UIViewController()
        generatorNavigator.rootViewController = UIViewController()
        settingsNavigator.rootViewController = UIViewController()

        let tabs: [TabRoute: MockRootNavigator] = [
            .vault(.list): vaultNavigator,
            .generator(.generator()): generatorNavigator,
            .settings(.settings(.tab)): settingsNavigator,
        ]
        subject.setNavigators(tabs)

        #expect(subject.navigator(for: TabRoute.generator(.generatorHistory)) === generatorNavigator)
        #expect(subject.navigator(for: TabRoute.vault(.addFolder)) === vaultNavigator)
        #expect(subject.navigator(for: TabRoute.settings(.about)) === settingsNavigator)
    }

    /// The shell has no tab bar: it is a plain container that shows the selected navigator and a bottom bar.
    @Test
    func setNavigators_showsSelectedNavigatorWithoutTabBar() {
        let vault = MockRootNavigator()
        let settings = MockRootNavigator()
        let vaultController = UIViewController()
        let settingsController = UIViewController()
        vault.rootViewController = vaultController
        settings.rootViewController = settingsController
        subject.setNavigators([TabRoute.vault(.list): vault, TabRoute.settings(.settings(.tab)): settings])

        let base: UIViewController = subject
        #expect(!(base is UITabBarController))
        #expect(vaultController.parent === subject)
        #expect(settingsController.parent == nil)
        #expect(subject.model.availableDestinations == [.vault, .settings])
    }

    /// Selecting an index or a destination swaps the shown navigator.
    @Test
    func selectedIndex_swapsChild() {
        let vault = MockRootNavigator()
        let settings = MockRootNavigator()
        let vaultController = UIViewController()
        let settingsController = UIViewController()
        vault.rootViewController = vaultController
        settings.rootViewController = settingsController
        subject.setNavigators([TabRoute.vault(.list): vault, TabRoute.settings(.settings(.tab)): settings])

        subject.selectedIndex = 1
        #expect(settingsController.parent === subject)
        #expect(vaultController.parent == nil)
        #expect(subject.model.destination == .settings)

        subject.model.select(.vault)
        #expect(vaultController.parent === subject)
        #expect(subject.selectedIndex == 0)
    }

    /// Re-applying the same navigators (as happens on a light/dark change) keeps the shown child.
    @Test
    func setNavigators_twiceKeepsChild() {
        let navigator = MockRootNavigator()
        let controller = UIViewController()
        navigator.rootViewController = controller
        subject.setNavigators([TabRoute.vault(.list): navigator])
        subject.setNavigators([TabRoute.vault(.list): navigator])
        #expect(controller.parent === subject)
        #expect(subject.children.filter { $0 === controller }.count == 1)
    }
}
