import os
import UIKit

#if DEBUG
/// Pass-Y perf (DEBUG only): navigation steps with the absolute time, in the same log as `PassYPerf.mark`
/// (`startup mark=nav.<step> t=<seconds>`), so a UI test can split "back tap -> previous page shown".
private let passYNavLogger = Logger(subsystem: "de.aiity.passy", category: "perf")
@inline(__always) private func passYNavMark(_ step: String) {
    let now = CFAbsoluteTimeGetCurrent()
    passYNavLogger.notice("startup mark=nav.\(step, privacy: .public) t=\(now, format: .fixed(precision: 3), privacy: .public)")
}

/// Pass-Y perf (DEBUG only): the frames of a push/pop transition (willShow -> didShow): the longest frame and the hitch
/// time (time beyond the display's frame interval), logged as `frameprobe frames=... maxGapMs=... hitchMs=...`.
@MainActor
private final class PassYTransitionFrameProbe: NSObject {
    static let shared = PassYTransitionFrameProbe()
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var frames = 0
    private var maxGap: CFTimeInterval = 0
    private var hitch: CFTimeInterval = 0

    func start() {
        link?.invalidate()
        frames = 0
        maxGap = 0
        hitch = 0
        last = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        guard let link else { return }
        link.invalidate()
        self.link = nil
        passYNavLogger.notice(
            "frameprobe frames=\(self.frames, privacy: .public) maxGapMs=\(self.maxGap * 1000, format: .fixed(precision: 1), privacy: .public) hitchMs=\(self.hitch * 1000, format: .fixed(precision: 1), privacy: .public)",
        )
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        guard last > 0 else { return }
        frames += 1
        let gap = link.timestamp - last
        let interval = max(link.targetTimestamp - link.timestamp, 1.0 / 120)
        maxGap = max(maxGap, gap)
        if gap > interval * 1.5 { hitch += gap - interval }
    }
}

@MainActor private func passYTransitionProbe(start: Bool) {
    start ? PassYTransitionFrameProbe.shared.start() : PassYTransitionFrameProbe.shared.stop()
}
#else
@inline(__always) private func passYNavMark(_ step: String) {}
@inline(__always) private func passYTransitionProbe(start: Bool) {}
#endif

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
        passYNavMark("pop")
        let popped = super.popViewController(animated: animated)
        stackChanged?()
        passYNavMark("popReturned")
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
        super.dismiss(animated: animated, completion: completion)
        logger.log("[Navigation] View dismissed: \(resolveLoggingViewName(for: self))")
    }

    // MARK: UINavigationControllerDelegate

    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool,
    ) {
        passYNavMark("willShow")
        if animated { passYTransitionProbe(start: true) }
        stackChanged?()
    }

    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool,
    ) {
        passYNavMark("didShow")
        passYTransitionProbe(start: false)
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
