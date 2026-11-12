import BitwardenKit
import BitwardenShared
import UIKit

/// A protocol for an `AppDelegate` that can be used by the `SceneDelegate` to look up the
/// `AppDelegate` when the app is running (`AppDelegate`) or testing (`TestingAppDelegate`).
///
@MainActor
protocol AppDelegateType: AnyObject {
    /// The processor that manages application level logic.
    var appProcessor: AppProcessor? { get }

    /// Whether the app is running for unit tests.
    var isTesting: Bool { get }
}

/// The app's `UIApplicationDelegate` which serves as the entry point into the app.
///
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, AppDelegateType {
    // MARK: Properties

    /// The processor that manages application level logic.
    var appProcessor: AppProcessor?

    /// Whether the app is running for unit tests.
    var isTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-testing")
    }

    // MARK: Menu bar / keyboard shortcuts

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        let commands: [UIMenuElement] = [
            UIKeyCommand(title: "New Login", action: #selector(passyNewLogin), input: "n", modifierFlags: .command),
            UIKeyCommand(title: "Copy Password", action: #selector(passyCopyPassword), input: "c",
                         modifierFlags: [.command, .shift]),
            UIKeyCommand(title: "Copy Verification Code", action: #selector(passyCopyCode), input: "c",
                         modifierFlags: [.command, .alternate]),
            UIKeyCommand(title: "Lock Vault", action: #selector(passyLockVault), input: "l", modifierFlags: .command),
        ]
        let menu = UIMenu(title: "Vault", identifier: UIMenu.Identifier("de.aiity.passy.menu.vault"), children: commands)
        builder.insertSibling(menu, afterMenu: .edit)
    }

    @objc private func passyNewLogin() { NotificationCenter.default.post(name: .passyNewLogin, object: nil) }
    @objc private func passyLockVault() { NotificationCenter.default.post(name: .passyLockVault, object: nil) }
    @objc private func passyCopyPassword() { NotificationCenter.default.post(name: .passyCopyPassword, object: nil) }
    @objc private func passyCopyCode() { NotificationCenter.default.post(name: .passyCopyCode, object: nil) }

    // MARK: Methods

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        // Exit early if testing to avoid running any app functionality.
        guard !isTesting else { return true }

        UNUserNotificationCenter.current().delegate = self

        let services = ServiceContainer.shared(
            application: UIApplication.shared,
            errorReporter: { ErrorReporterFactory.makeDefaultErrorReporter() },
            nfcReaderService: { DefaultNFCReaderService() },
        )
        let appModule = DefaultAppModule(services: services)
        appProcessor = AppProcessor(appModule: appModule, services: services)
        return true
    }

    /// Successfully registered for push notifications.
    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        appProcessor?.didRegister(withToken: deviceToken)
    }

    /// Record an error if registering for push notifications failed.
    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        appProcessor?.failedToRegister(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    ) async -> UIBackgroundFetchResult {
        await appProcessor?.messageReceived(userInfo)
        return .newData
    }

    /// Received a response to a push notification alert.
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        await appProcessor?.messageReceived(
            response.notification.request.content.userInfo,
            notificationDismissed: response.actionIdentifier == UNNotificationDismissActionIdentifier,
            notificationTapped: response.actionIdentifier == UNNotificationDefaultActionIdentifier,
        )
    }

    /// Received a message in the foreground of the app.
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
        await appProcessor?.messageReceived(notification.request.content.userInfo)
        return .banner
    }
}
