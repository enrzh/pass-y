import BitwardenKitMocks
import XCTest

@testable import Bitwarden
@testable import BitwardenShared

// MARK: - SceneDelegateTests

class SceneDelegateTests: BitwardenTestCase {
    // MARK: Properties

    var appModule: MockAppModule!
    var subject: SceneDelegate!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        appModule = MockAppModule()
        subject = SceneDelegate()
    }

    override func tearDown() {
        super.tearDown()
        appModule = nil
        subject = nil
    }

    // MARK: Tests

    /// `scene(_:willConnectTo:options:)` with a `UIWindowScene` creates the app's UI.
    @MainActor
    func test_sceneWillConnectTo_withWindowScene() throws {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor

        let session = TestInstanceFactory.create(UISceneSession.self)
        let scene = TestInstanceFactory.create(UIWindowScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)
        subject.scene(scene, willConnectTo: session, options: options)

        waitFor(!subject.isStartingUp)

        XCTAssertNotNil(appProcessor.coordinator)
        XCTAssertFalse(subject.isStartingUp)
        XCTAssertNotNil(subject.splashWindow)
        XCTAssertEqual(subject.splashWindow?.alpha, 0)
        XCTAssertNotNil(subject.window)
        XCTAssertTrue(appModule.appCoordinator.isStarted)
    }

    /// No multi-tap recognizer of the app on its window delays or swallows touches: one with
    /// `delaysTouchesEnded` (the UIKit default) held back every touch-up of Back, Cancel and Close by ~360 ms.
    @MainActor
    func test_sceneWillConnectTo_windowRecognizersDoNotDelayTouches() throws {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor

        let session = TestInstanceFactory.create(UISceneSession.self)
        let scene = TestInstanceFactory.create(UIWindowScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)
        subject.scene(scene, willConnectTo: session, options: options)
        waitFor(!subject.isStartingUp)

        // The app's own multi-tap recognizers (the system adds single-tap and gate recognizers of its own).
        let window = try XCTUnwrap(subject.window)
        let multiTap = (window.gestureRecognizers ?? [])
            .compactMap { $0 as? UITapGestureRecognizer }
            .filter { $0.numberOfTapsRequired > 1 }
        for recognizer in multiTap {
            XCTAssertFalse(recognizer.delaysTouchesBegan, "\(recognizer) delays touch-down")
            XCTAssertFalse(recognizer.delaysTouchesEnded, "\(recognizer) delays touch-up")
            XCTAssertFalse(recognizer.cancelsTouchesInView, "\(recognizer) swallows touches")
        }
    }

    /// `scene(_:willConnectTo:options:)` without a `UIWindowScene` fails to create the app's UI.
    @MainActor
    func test_sceneWillConnectTo_withNonWindowScene() throws {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor

        let session = TestInstanceFactory.create(UISceneSession.self)
        let scene = TestInstanceFactory.create(UIScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)
        subject.scene(scene, willConnectTo: session, options: options)

        XCTAssertNil(appProcessor.coordinator)
        XCTAssertNil(subject.splashWindow)
        XCTAssertNil(subject.window)
        XCTAssertFalse(appModule.appCoordinator.isStarted)
    }

    /// `sceneWillResignActive(_:)` sets the privacy window's alpha to 1,
    /// which hides the app behind the privacy window in the app switcher.
    @MainActor
    func test_sceneWillResignActive() {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor

        let session = TestInstanceFactory.create(UISceneSession.self)
        let scene = TestInstanceFactory.create(UIWindowScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)
        subject.scene(scene, willConnectTo: session, options: options)

        subject.sceneWillResignActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1)
    }

    /// Connects the scene with a fresh app processor and waits until the start-up cover is gone.
    @MainActor
    private func connectedScene() -> UIWindowScene {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor
        let session = TestInstanceFactory.create(UISceneSession.self)
        let scene = TestInstanceFactory.create(UIWindowScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)
        subject.scene(scene, willConnectTo: session, options: options)
        waitFor(!subject.isStartingUp)
        waitFor(subject.splashWindow?.alpha == 0)
        return scene
    }

    /// The Face ID / Touch ID prompt of an unlock resigns the scene: the locked unlock page is not covered (the cover
    /// and its fade-out were the black screen after Face ID). Leaving for the background always covers, and an unlock
    /// that ends while the scene is still inactive covers before the vault shows, then uncovers without the fade.
    @MainActor
    func test_privacyCover_biometricUnlock() {
        let scene = connectedScene()
        defer { PassYPrivacyCover.endBiometricUnlock() }

        PassYPrivacyCover.beginBiometricUnlock()
        subject.sceneWillResignActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 0, "no cover for the biometric prompt")

        subject.sceneDidEnterBackground(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "the app switcher snapshot is always covered")
        subject.sceneDidBecomeActive(scene)
        waitFor(subject.splashWindow?.alpha == 0)

        // The test scene is never foreground-active: the unlock ends while it counts as inactive.
        PassYPrivacyCover.endBiometricUnlock()
        XCTAssertFalse(PassYPrivacyCover.isBiometricUnlockInProgress)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "covered before the vault can show")
        subject.sceneDidBecomeActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 0, "uncovered at once, no fade")

        subject.sceneWillResignActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "any other resign covers as before")
    }

    /// `scene(_:continue)` runs successfully
    @MainActor
    func test_sceneContinue() {
        let appProcessor = AppProcessor(
            appModule: appModule,
            services: ServiceContainer(errorReporter: MockErrorReporter()),
        )
        (UIApplication.shared.delegate as? TestingAppDelegate)?.appProcessor = appProcessor

        let session = TestInstanceFactory.create(UISceneSession.self)
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = URL(string: "https://example.com")
        let scene = TestInstanceFactory.create(UIWindowScene.self, properties: [
            "session": session,
        ])
        let options = TestInstanceFactory.create(UIScene.ConnectionOptions.self)

        subject.scene(scene, willConnectTo: session, options: options)
        subject.scene(scene, continue: userActivity)
        XCTAssertEqual(subject.splashWindow?.alpha, 1)
    }
}
