import BitwardenKit
import UIKit

// MARK: - BitwardenTabBarController

/// A `UITabBarController` subclass conforming to `TabNavigator`. This class manages
/// a set of tabs and handles dynamic appearance changes between light/dark mode.
///
class BitwardenTabBarController: UITabBarController, TabNavigator {
    // MARK: Properties

    /// The tabs used in the UITabBarController, mapping each `TabRoute` to its respective `Navigator`.
    private var tabsAndNavigators: [TabRoute: any Navigator] = [:]

    // MARK: AlertPresentable

    var rootViewController: UIViewController? {
        self
    }

    // MARK: TabNavigator

    func navigator<Tab: TabRepresentable>(for tab: Tab) -> Navigator? {
        if let tabRoute = tab as? TabRoute {
            return tabsAndNavigators.first(where: { $0.key.index == tabRoute.index })?.value
        }
        return viewControllers?[tab.index] as? Navigator
    }

    func setNavigators<Tab: Hashable & TabRepresentable>(_ tabs: [Tab: Navigator]) {
        tabsAndNavigators = tabs as? [TabRoute: Navigator] ?? [:]

        let sortedTabs = tabs.sorted { $0.key.index < $1.key.index }
        let controllers: [(tab: Tab, controller: UIViewController)] = sortedTabs.compactMap { tab in
            guard let viewController = tab.value.rootViewController else { return nil }
            viewController.tabBarItem.title = tab.key.title
            viewController.tabBarItem.image = tab.key.image
            viewController.tabBarItem.selectedImage = tab.key.selectedImage
            return (tab.key, viewController)
        }

        if #available(iOS 18.0, *) {
            // Re-applying the same tabs (e.g. on a light/dark change) must update the existing `UITab`s in
            // place: replacing them re-resolves view controllers that are already installed, which UIKit
            // rejects with an assertion (crash on every appearance switch).
            if self.tabs.map(\.identifier) == controllers.map({ "\($0.tab.index)" }) {
                for (uiTab, entry) in zip(self.tabs, controllers) {
                    uiTab.title = entry.tab.title
                    uiTab.image = entry.tab.image
                    if #available(iOS 26.1, *) { uiTab.selectedImage = entry.tab.selectedImage }
                }
                return
            }
            // Native adaptive navigation: tab bar in compact widths, sidebar on iPad / wide windows (and Mac).
            self.tabs = controllers.map { entry in
                let uiTab = UITab(
                    title: entry.tab.title,
                    image: entry.tab.image,
                    identifier: "\(entry.tab.index)",
                ) { _ in entry.controller }
                // `UITab.selectedImage` only exists on iOS 26.1+; older systems derive the filled variant themselves.
                if #available(iOS 26.1, *) { uiTab.selectedImage = entry.tab.selectedImage }
                return uiTab
            }
            mode = .tabSidebar
            // The tab providers are lazy; resolve them now so `viewControllers` (used by `navigator(for:)`) is populated.
            self.tabs.forEach { _ = $0.viewController }
        } else {
            viewControllers = controllers.map(\.controller)
        }
    }

    // MARK: Lifecycle

    /// Called when the trait collection (such as light/dark mode) changes.
    ///
    /// UIKit does not seem to refresh the tab bar icon images dynamically when switching between
    /// light/dark mode in mid-session. This override ensures the icons update correctly by re-applying
    /// the navigators with the current tabs.
    ///
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNavigators(tabsAndNavigators)
        }
    }
}
