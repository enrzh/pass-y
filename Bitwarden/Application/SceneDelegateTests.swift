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
    /// and its fade-out were the black screen after Face ID). Leaving for the background always covers.
    @MainActor
    func test_privacyCover_biometricPrompt_noCoverButBackgroundCovers() {
        let scene = connectedScene()
        defer { PassYPrivacyCover.endBiometricUnlock() }

        PassYPrivacyCover.beginBiometricUnlock()
        subject.sceneWillResignActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 0, "no cover for the biometric prompt")

        subject.sceneDidEnterBackground(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "the app switcher snapshot is always covered")
    }

    /// A successful unlock that ends while the scene is inactive (the system Face ID UI still fading) does not cover
    /// the vault; the scene becoming active ends that state without any cover.
    @MainActor
    func test_privacyCover_successWhileInactive_noCover() {
        let scene = connectedScene()

        // The test scene is never foreground-active: the unlock ends while it counts as inactive.
        PassYPrivacyCover.beginBiometricUnlock()
        subject.sceneWillResignActive(scene)
        PassYPrivacyCover.endBiometricUnlock(succeeded: true)
        XCTAssertFalse(PassYPrivacyCover.isBiometricUnlockInProgress)
        XCTAssertEqual(subject.splashWindow?.alpha, 0, "the unlocked vault is not covered")
        XCTAssertTrue(subject.isUncoveredAfterBiometricUnlock)
        XCTAssertFalse(subject.isCoverForBiometricUnlockEnd)

        subject.sceneDidBecomeActive(scene)
        XCTAssertFalse(subject.isUncoveredAfterBiometricUnlock)
        XCTAssertEqual(subject.splashWindow?.alpha, 0)

        subject.sceneWillResignActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "a resign without an unlock (app switcher, call) covers")
    }

    /// Going to the background while a successful unlock left the vault uncovered covers before the snapshot.
    @MainActor
    func test_privacyCover_successWhileInactive_thenBackground_covers() {
        let scene = connectedScene()

        PassYPrivacyCover.beginBiometricUnlock()
        PassYPrivacyCover.endBiometricUnlock(succeeded: true)
        XCTAssertEqual(subject.splashWindow?.alpha, 0)

        subject.sceneDidEnterBackground(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "covered before the app switcher snapshot")
        XCTAssertFalse(subject.isUncoveredAfterBiometricUnlock)
    }

    /// A failed or cancelled unlock that ends while the scene is inactive covers as before, and uncovers without the
    /// fade when the scene becomes active.
    @MainActor
    func test_privacyCover_failureWhileInactive_covers() {
        let scene = connectedScene()

        PassYPrivacyCover.beginBiometricUnlock()
        PassYPrivacyCover.endBiometricUnlock()
        XCTAssertEqual(subject.splashWindow?.alpha, 1, "a cancelled or failed unlock covers while inactive")
        XCTAssertTrue(subject.isCoverForBiometricUnlockEnd)
        XCTAssertFalse(subject.isUncoveredAfterBiometricUnlock)

        subject.sceneDidBecomeActive(scene)
        XCTAssertEqual(subject.splashWindow?.alpha, 0, "uncovered at once, no fade")
        XCTAssertFalse(subject.isCoverForBiometricUnlockEnd)
    }

    /// An unlock that ends while the scene is active changes nothing, success or not.
    @MainActor
    func test_privacyCover_unlockEndWhileActive_noChange() {
        _ = connectedScene()

        subject.biometricUnlockEnded(succeeded: true, sceneActive: true)
        subject.biometricUnlockEnded(succeeded: false, sceneActive: true)
        XCTAssertEqual(subject.splashWindow?.alpha, 0)
        XCTAssertFalse(subject.isUncoveredAfterBiometricUnlock)
        XCTAssertFalse(subject.isCoverForBiometricUnlockEnd)
    }

    /// The window and the root show the vault home's background, never the launch screen black/white in the gap.
    @MainActor
    func test_window_background_matchesHome() {
        _ = connectedScene()
        XCTAssertEqual(subject.window?.backgroundColor, .systemGroupedBackground)
        XCTAssertEqual(subject.window?.rootViewController?.view.backgroundColor, .systemGroupedBackground)
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
