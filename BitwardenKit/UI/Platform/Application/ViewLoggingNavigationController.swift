import UIKit

// MARK: - ViewLoggingNavigationController

/// A `UINavigationController` which logs when views appear and are dismissed as a user is
/// navigating throughout the app.
///
/// For this to work throughout the application, this needs to be consistently used in place of
/// `UINavigationController` *or* the `delegate` and `presentationController?.delegate` need to be
/// passed from an existing navigation controller to any newly created `UINavigationController`.
///
public class ViewLoggingNavigationController: UINavigationController,
    UINavigationControllerDelegate,
    UIAdaptivePresentationControllerDelegate {
    // MARK: Properties

    /// The logger instance used to log when views appear and are dismissed.
    let logger: BitwardenLogger

    /// Called when the stack changes: right after a push, pop, pop to root or `setViewControllers` (no window needed),
    /// and around interactive swipe-back transitions (`willShow`/`didShow`).
    /// UIKit publishes no KVO for pushes, so the shell uses this instead of polling the stack.
    public var stackChanged: (() -> Void)?

    // MARK: Initialization

    /// Initialize a `ViewLoggingNavigationController`.
    ///
    /// - Parameter logger: The logger instance used to log when views appear and are dismissed.
    ///
    public init(logger: BitwardenLogger) {
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        presentationController?.delegate = self
    }

    // MARK: UINavigationController

    override public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        stackChanged?()
    }

    @discardableResult
    override public func popViewController(animated: Bool) -> UIViewController? {
        #if DEBUG
        PassYNavigationProbe.mark("pop")
        #endif
        let popped = super.popViewController(animated: animated)
        stackChanged?()
        #if DEBUG
        PassYNavigationProbe.mark("popReturned")
        #endif
        return popped
    }

    @discardableResult
    override public func popToRootViewController(animated: Bool) -> [UIViewController]? {
        let popped = super.popToRootViewController(animated: animated)
        stackChanged?()
        return popped
    }

    @discardableResult
    override public func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        let popped = super.popToViewController(viewController, animated: animated)
        stackChanged?()
        return popped
    }

    override public func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        stackChanged?()
    }

    override public func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        #if DEBUG
        PassYNavigationProbe.mark("dismiss")
        if animated { PassYNavigationProbe.shared.startTransition() }
        super.dismiss(animated: animated) {
            PassYNavigationProbe.mark("dismissed")
            PassYNavigationProbe.shared.endTransition()
            completion?()
        }
        #else
        super.dismiss(animated: animated, completion: completion)
        #endif
        logger.log("[Navigation] View dismissed: \(resolveLoggingViewName(for: self))")
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool,
    ) {
        #if DEBUG
        PassYNavigationProbe.mark("willShow")
        if animated { PassYNavigationProbe.shared.startTransition() }
        #endif
        stackChanged?()
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool,
    ) {
        #if DEBUG
        PassYNavigationProbe.mark("didShow")
        PassYNavigationProbe.shared.endTransition()
        #endif
        logger.log("[Navigation] View appeared: \(resolveLoggingViewName(for: viewController))")
        stackChanged?()
    }

    // MARK: UIAdaptivePresentationControllerDelegate

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController
        logger.log("[Navigation] View dismissed interactively: \(resolveLoggingViewName(for: viewController))")
    }

    // MARK: Private

    /// Returns the view's name for the purpose of logging. This attempts to unwrap
    /// `UIHostingController`s and `UINavigationController`s to log a more descriptive name of the
    /// view contained within these container view controllers.
    ///
    /// - Parameter viewController: The view controller for which to determine the name of the view
    ///     for logging purposes.
    /// - Returns: The view's name for logging purposes.
    ///
    private func resolveLoggingViewName(for viewController: UIViewController) -> String {
        let viewType = String(describing: type(of: viewController))
        if viewType.contains("HostingController") {
            guard let start = viewType.firstIndex(of: "<"),
                  let end = viewType.firstIndex(of: ">"),
                  start < end else {
                return viewType
            }
            let innerType = viewType[viewType.index(after: start) ..< end]
            return String(innerType)
        } else if let navigationController = viewController as? UINavigationController,
                  let visibleViewController = navigationController.visibleViewController {
            return resolveLoggingViewName(for: visibleViewController)
        } else {
            return viewType
        }
    }
}
