import BitwardenKit
import Combine
import SwiftUI
import UIKit

// MARK: - PassYBarContainerView

/// Hosts the bar. SwiftUI's hosting view answers every touch inside its frame, also where the bar draws nothing; this
/// container hands such touches to the page below and only keeps the ones on a bar control. UIKit controls inside the
/// bar (the search field, the menu button) are deeper views and are always hit.
final class PassYBarContainerView: UIView {
    /// The model with the frames of the bar controls.
    let model: PassYShellModel

    /// The hosting view of the bar.
    let hostView: UIView

    init(hostView: UIView, model: PassYShellModel) {
        self.hostView = hostView
        self.model = model
        super.init(frame: .zero)
        backgroundColor = .clear
        hostView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostView)
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: topAnchor),
            hostView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event), hit !== self else { return nil }
        guard hit === hostView else { return hit }
        let inset: CGFloat = -4
        return model.controlFrames.contains { $0.insetBy(dx: inset, dy: inset).contains(point) } ? hit : nil
    }
}

// MARK: - PassYEdgeFadeView

/// A touch-transparent progressive fade of the page color at the top or bottom edge (a gradient mask in the spirit of
/// the iOS 26 soft scroll edge effect): opaque at the screen edge, fading to nothing over `softHeight` points beyond
/// the bar. No blur block, no hard edge.
final class PassYEdgeFadeView: UIView {
    enum Edge { case top, bottom }

    /// The length of the soft part, beyond the bar.
    static let softHeight: CGFloat = 22

    /// The opacity at the screen edge.
    static let edgeOpacity: CGFloat = 0.94

    let edge: Edge
    private let gradient = CAGradientLayer()

    init(edge: Edge) {
        self.edge = edge
        super.init(frame: .zero)
        // The gradient never animates: no implicit CALayer animation when frame, points, locations or colors change
        // (a layer that is laid out often would restart a 0.25 s animation each time and keep the app from idling).
        gradient.actions = [
            "bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "colors": NSNull(),
            "locations": NSNull(), "startPoint": NSNull(), "endPoint": NSNull(), "opacity": NSNull(),
        ]
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        accessibilityIdentifier = edge == .top ? "PassYTopFade" : "PassYBottomFade"
        isAccessibilityElement = false
        layer.addSublayer(gradient)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        gradient.frame = bounds
        // Opaque over the bar, soft over the last `softHeight` points.
        let soft = min(Self.softHeight / max(bounds.height, 1), 1)
        let solid = NSNumber(value: Double(1 - soft))
        switch edge {
        case .top:
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            gradient.locations = [0, solid, 1]
        case .bottom:
            gradient.startPoint = CGPoint(x: 0.5, y: 1)
            gradient.endPoint = CGPoint(x: 0.5, y: 0)
            gradient.locations = [0, 0.55, 1]
        }
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateColors()
    }

    private func updateColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let base = UIColor.systemGroupedBackground.resolvedColor(with: traitCollection)
        let strong = base.withAlphaComponent(Self.edgeOpacity).cgColor
        let clear = base.withAlphaComponent(0).cgColor
        // An eased ramp (a smooth step) so the fade has no visible start.
        gradient.colors = edge == .top ? [strong, strong, clear] : [strong, base.withAlphaComponent(0.7).cgColor, clear]
    }
}

// MARK: - PassYShellController

/// The root shell of the signed-in app. It shows one top-level navigator at a time (Vault, Send, Generator or
/// Settings; they are chosen from the avatar menu, there is no tab bar) and keeps the search bar pinned to the bottom
/// of the screen on every page, also on pushed pages. It conforms to `TabNavigator`, so the coordinators keep working.
///
class PassYShellController: UIViewController, TabNavigator {
    // MARK: Properties

    /// The model shared with the bottom bar and the avatar menu.
    let model: PassYShellModel

    // MARK: Private Properties

    /// The hosting controller of the persistent bottom bar.
    private var barHost: UIHostingController<PassYShellBar>?

    /// The container of the bar host that lets touches outside the controls through.
    private var barContainer: PassYBarContainerView?

    /// The progressive fade under the bar (ui-r9). Pages scroll under the bar and the home indicator; there is no solid
    /// strip any more.
    private let bottomFade = PassYEdgeFadeView(edge: .bottom)

    /// The fades under the navigation bars of the shell's stacks, kept to remove them again.
    private var topFades: [PassYEdgeFadeView] = []

    /// The container for the selected navigator.
    private let contentView = UIView()

    /// The shown child view controller.
    private var currentChild: UIViewController?

    /// The navigators sorted by their route index.
    private var entries: [(index: Int, navigator: any Navigator)] = []

    /// The route index of the selected navigator.
    private var selectedRouteIndex = 0

    /// The tabs by route, to answer `navigator(for:)`.
    private var tabsAndNavigators: [TabRoute: any Navigator] = [:]

    /// Subscriptions to the shared model.
    private var cancellables = Set<AnyCancellable>()

    /// Observations of the navigation stacks (the Vault button depends on the depth of the vault stack).
    private var stackObservations: [NSKeyValueObservation] = []

    // MARK: Initialization

    /// Creates the shell.
    ///
    /// - Parameter model: The model shared with the bottom bar and the avatar menu.
    ///
    @MainActor
    init(model: PassYShellModel? = nil) {
        self.model = model ?? PassYShellModel.shared
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Navigator

    var rootViewController: UIViewController? {
        self
    }

    // MARK: TabNavigator

    var selectedIndex: Int {
        get { entries.firstIndex { $0.index == selectedRouteIndex } ?? 0 }
        set {
            guard entries.indices.contains(newValue) else { return }
            show(routeIndex: entries[newValue].index, resetSearch: false)
        }
    }

    func navigator<Tab: TabRepresentable>(for tab: Tab) -> Navigator? {
        if let tabRoute = tab as? TabRoute {
            return tabsAndNavigators.first(where: { $0.key.index == tabRoute.index })?.value
        }
        return entries.first(where: { $0.index == tab.index })?.navigator
    }

    func setNavigators<Tab: Hashable & TabRepresentable>(_ tabs: [Tab: Navigator]) {
        tabsAndNavigators = tabs as? [TabRoute: Navigator] ?? [:]
        entries = tabs
            .sorted { $0.key.index < $1.key.index }
            .map { (index: $0.key.index, navigator: $0.value) }
        model.availableDestinations = entries.compactMap { PassYDestination(rawValue: $0.index) }
        observeStacks()

        // Keep the selection if it still exists (for example when Send is switched off by policy).
        let target = entries.contains { $0.index == selectedRouteIndex }
            ? selectedRouteIndex
            : (entries.first?.index ?? 0)
        show(routeIndex: target, resetSearch: false)
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let host = UIHostingController(rootView: PassYShellBar(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        let container = PassYBarContainerView(hostView: host.view, model: model)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        host.didMove(toParent: self)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.heightAnchor.constraint(
                equalToConstant: PassYShellBar.barHeight + PassYShellBar.fadeHeight,
            ),
            // Rests on the bottom safe area; rides above the keyboard while the search field is edited.
            container.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
        view.insertSubview(bottomFade, belowSubview: container)
        NSLayoutConstraint.activate([
            bottomFade.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomFade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomFade.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomFade.topAnchor.constraint(equalTo: container.topAnchor, constant: -PassYEdgeFadeView.softHeight),
        ])
        barContainer = container
        barHost = host

        #if DEBUG
        PassYAnimationDump.installOnce()
        #endif

        model.goToVault = { [weak self] in self?.showVaultHome() }
        model.selectDestination = { [weak self] destination in
            guard let self else { return }
            let reselect = destination == model.destination
            show(routeIndex: destination.rawValue, resetSearch: true)
            if reselect { popToRoot() }
        }

        // Typing in the bar on a page that cannot search (Settings, Generator, an item) opens the vault search.
        Publishers.CombineLatest(model.$isEditing, model.$text)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] editing, text in
                guard let self, editing || !text.isEmpty, model.activeTarget == nil else { return }
                routeToSearch()
            }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Pages end where the bar content begins (also above the keyboard), so lists and forms clear the bar.
        guard let host = barContainer else { return }
        let barTop = host.frame.minY + PassYShellBar.fadeHeight
        let inset = max(0, view.bounds.height - barTop - view.safeAreaInsets.bottom)
        if currentChild?.additionalSafeAreaInsets.bottom != inset {
            currentChild?.additionalSafeAreaInsets.bottom = inset
        }
        view.bringSubviewToFront(bottomFade)
        view.bringSubviewToFront(host)
        updateVaultHome()
    }

    // MARK: Private Methods

    /// Observes the stacks of all navigators so the Vault button follows pushes, pops and pop-to-root. UIKit publishes
    /// no KVO for pushes, so this is event driven through `ViewLoggingNavigationController.stackChanged` (push, pop, swipe-back);
    /// there is no timer. KVO on `viewControllers` still covers `setViewControllers` and replaced roots.
    private func observeStacks() {
        topFades.forEach { $0.removeFromSuperview() }
        topFades = []
        let navigations = entries.compactMap { $0.navigator.rootViewController as? UINavigationController }
        stackObservations = navigations.map { navigation in
            navigation.observe(\.viewControllers) { [weak self] _, _ in
                // KVO fires while the stack changes; read it after the change settled.
                DispatchQueue.main.async { self?.updateVaultHome() }
            }
        }
        for navigation in navigations {
            installTopFade(in: navigation)
            // The app's navigators are `ViewLoggingNavigationController`s: they report every push and pop.
            (navigation as? ViewLoggingNavigationController)?.stackChanged = { [weak self] in self?.updateVaultHome() }
        }
        updateVaultHome()
    }

    /// ui-r9: the navigation bar has no background of its own (no blur block behind a collapsed bar). A progressive fade
    /// of the page color sits between the page and the bar instead, so content fades out as it scrolls under the bar.
    private func installTopFade(in navigation: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        let bar = navigation.navigationBar
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance

        let fade = PassYEdgeFadeView(edge: .top)
        navigation.view.insertSubview(fade, belowSubview: bar)
        NSLayoutConstraint.activate([
            fade.leadingAnchor.constraint(equalTo: navigation.view.leadingAnchor),
            fade.trailingAnchor.constraint(equalTo: navigation.view.trailingAnchor),
            fade.topAnchor.constraint(equalTo: navigation.view.topAnchor),
            // The inline bar only (status bar plus 44 pt): the fade must not cover an expanded large title.
            fade.bottomAnchor.constraint(
                equalTo: navigation.view.safeAreaLayoutGuide.topAnchor,
                constant: 44 + PassYEdgeFadeView.softHeight,
            ),
        ])
        topFades.append(fade)
    }

    /// Whether the vault home (root of the vault stack) is what the user sees.
    private func updateVaultHome() {
        let vaultNavigation = entries.first { $0.index == PassYDestination.vault.rawValue }?.navigator
            .rootViewController as? UINavigationController
        let atRoot = (vaultNavigation?.viewControllers.count ?? 1) <= 1
        let atHome = model.destination == .vault && atRoot
        if model.isAtVaultHome != atHome { model.isAtVaultHome = atHome }
    }

    /// The Vault button: switch to the vault, pop to its root and clear the search.
    private func showVaultHome() {
        show(routeIndex: PassYDestination.vault.rawValue, resetSearch: true)
        model.cancelSearch()
        popToRoot()
        updateVaultHome()
    }

    /// Pops the selected navigator to its root.
    private func popToRoot() {
        (entries.first { $0.index == selectedRouteIndex }?.navigator.rootViewController as? UINavigationController)?
            .popToRootViewController(animated: UI.animated)
    }

    /// Shows the vault (or Send) root so the search text can be consumed.
    private func routeToSearch() {
        if model.destination != .vault, model.destination != .send {
            show(routeIndex: PassYDestination.vault.rawValue, resetSearch: false)
        }
        popToRoot()
    }

    /// Shows the navigator for a route index.
    private func show(routeIndex: Int, resetSearch: Bool) {
        guard let entry = entries.first(where: { $0.index == routeIndex }),
              let child = entry.navigator.rootViewController else { return }
        let changed = selectedRouteIndex != routeIndex
        selectedRouteIndex = routeIndex
        if let destination = PassYDestination(rawValue: routeIndex) { model.destination = destination }
        if changed, resetSearch { model.cancelSearch() }
        defer { updateVaultHome() }
        guard currentChild !== child else { return }

        currentChild?.willMove(toParent: nil)
        currentChild?.view.removeFromSuperview()
        currentChild?.removeFromParent()

        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            child.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            child.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        child.didMove(toParent: self)
        currentChild = child
        view.setNeedsLayout()
    }
}
