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

    /// Windows of finished tests stay alive (hidden): a navigation bar lays out in a deferred CA commit, and a window
    /// that is deallocated by then crashes UIKit ("Cannot form weak reference to ... UIWindow").
    nonisolated(unsafe) private static var retainedWindows: [UIWindow] = []

    init() {
        Self.retainedWindows.forEach { $0.isHidden = true }
        window = UIWindow(frame: UIScreen.main.bounds)
        Self.retainedWindows.append(window)
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

    // MARK: Vault button (ui-r8)

    /// Two navigators with real navigation controllers: vault and settings.
    private func makeStacks() -> (vault: ViewLoggingNavigationController, settings: ViewLoggingNavigationController) {
        let vault = MockRootNavigator()
        let settings = MockRootNavigator()
        let vaultStack = ViewLoggingNavigationController(logger: MockBitwardenLogger())
        let settingsStack = ViewLoggingNavigationController(logger: MockBitwardenLogger())
        vaultStack.setViewControllers([UIViewController()], animated: false)
        settingsStack.setViewControllers([UIViewController()], animated: false)
        vault.rootViewController = vaultStack
        settings.rootViewController = settingsStack
        subject.setNavigators([TabRoute.vault(.list): vault, TabRoute.settings(.settings(.tab)): settings])
        return (vaultStack, settingsStack)
    }

    /// Waits (at most one second) until `condition` holds.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 100 {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return condition()
    }

    /// On the vault home the Vault button is hidden; a pushed page shows it (follows the stack by KVO).
    @Test
    func vaultButton_followsPushAndPop() async {
        let stacks = makeStacks()
        #expect(subject.model.isAtVaultHome)

        stacks.vault.pushViewController(UIViewController(), animated: false)
        #expect(await eventually { !subject.model.isAtVaultHome })

        stacks.vault.popViewController(animated: false)
        #expect(await eventually { subject.model.isAtVaultHome })

        stacks.vault.pushViewController(UIViewController(), animated: false)
        stacks.vault.pushViewController(UIViewController(), animated: false)
        #expect(await eventually { !subject.model.isAtVaultHome })
        stacks.vault.popToRootViewController(animated: false)
        #expect(await eventually { subject.model.isAtVaultHome })
    }

    /// ui-r9: no polling timer. The model follows a push in the same call (delegate `willShow`), without the run loop
    /// turning once.
    @Test
    func vaultButton_isEventDriven_noPolling() {
        let stacks = makeStacks()
        stacks.vault.pushViewController(UIViewController(), animated: false)
        #expect(!subject.model.isAtVaultHome, "updated synchronously by the push, not by a timer")
        stacks.vault.popViewController(animated: false)
        #expect(subject.model.isAtVaultHome)
    }

    /// ui-r9: a `ViewLoggingNavigationController` reports pushes through `stackChanged` (the app's real navigators).
    @Test
    func vaultButton_followsViewLoggingNavigationController() {
        let vault = MockRootNavigator()
        let vaultStack = ViewLoggingNavigationController(logger: MockBitwardenLogger())
        vaultStack.setViewControllers([UIViewController()], animated: false)
        vault.rootViewController = vaultStack
        subject.setNavigators([TabRoute.vault(.list): vault])
        _ = vaultStack.view // viewDidLoad sets the delegate
        vaultStack.pushViewController(UIViewController(), animated: false)
        #expect(!subject.model.isAtVaultHome)
        vaultStack.popToRootViewController(animated: false)
        #expect(subject.model.isAtVaultHome)
    }

    /// ui-r9: the shell source has no repeating timer and no solid strip behind the bar.
    @Test
    func shell_hasNoTimerAndNoSolidBacking() throws {
        let source = try String(contentsOfFile: #filePath.replacingOccurrences(of: "Tests.swift", with: ".swift"), encoding: .utf8)
        #expect(!source.contains("Timer("), "no timer in the shell")
        #expect(!source.contains("scheduledTimer"))
        #expect(!source.contains("bottomBacking"), "no solid strip behind the bar")
    }

    /// ui-r9: a fade (touch transparent) sits under the bar, and every stack of the shell gets a top fade below its bar.
    @Test
    func fades_existAndLetTouchesThrough() {
        let stacks = makeStacks()
        _ = subject.view
        let bottom = subject.view.subviews.compactMap { $0 as? PassYEdgeFadeView }.first { $0.edge == .bottom }
        #expect(bottom != nil)
        #expect(bottom?.isUserInteractionEnabled == false)
        let top = stacks.vault.view.subviews.compactMap { $0 as? PassYEdgeFadeView }.first
        #expect(top?.edge == .top)
        #expect(top?.isUserInteractionEnabled == false)
        let barIndex = stacks.vault.view.subviews.firstIndex(of: stacks.vault.navigationBar) ?? 0
        let fadeIndex = stacks.vault.view.subviews.firstIndex { $0 is PassYEdgeFadeView } ?? 99
        #expect(fadeIndex < barIndex, "the fade is below the bar so bar buttons stay sharp")
    }

    /// Other destinations show the Vault button; it returns to the vault and pops its stack to the root.
    @Test
    func vaultButton_returnsToVaultHome() async {
        let stacks = makeStacks()
        stacks.vault.pushViewController(UIViewController(), animated: false)
        subject.model.select(.settings)
        #expect(subject.model.destination == .settings)
        #expect(!subject.model.isAtVaultHome)

        subject.model.goToVault?()
        #expect(subject.model.destination == .vault)
        #expect(stacks.vault.viewControllers.count == 1, "vault stack popped to its root")
        #expect(subject.model.isAtVaultHome)
        #expect(stacks.vault.parent === subject)
    }

    /// The Vault button also clears a running search.
    @Test
    func vaultButton_cancelsSearch() async {
        _ = makeStacks()
        subject.model.select(.settings)
        subject.model.text = "abc"
        subject.model.isEditing = true
        subject.model.goToVault?()
        #expect(subject.model.text.isEmpty)
        #expect(!subject.model.isEditing)
    }
}
