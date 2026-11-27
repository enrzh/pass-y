import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import InlineSnapshotTesting
import TestHelpers
import XCTest

@testable import BitwardenShared
@testable import BitwardenSharedMocks

class AboutProcessorTests: BitwardenTestCase {
    // MARK: Properties

    var appInfoService: MockAppInfoService!
    var configService: MockConfigService!
    var coordinator: MockCoordinator<SettingsRoute, SettingsEvent>!
    var environmentService: MockEnvironmentService!
    var errorReporter: MockErrorReporter!
    var flightRecorder: MockFlightRecorder!
    var pasteboardService: MockPasteboardService!
    var subject: AboutProcessor!

    // MARK: Setup and Teardown

    override func setUp() {
        super.setUp()

        appInfoService = MockAppInfoService()
        configService = MockConfigService()
        coordinator = MockCoordinator<SettingsRoute, SettingsEvent>()
        environmentService = MockEnvironmentService()
        errorReporter = MockErrorReporter()
        flightRecorder = MockFlightRecorder()
        pasteboardService = MockPasteboardService()

        subject = AboutProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                appInfoService: appInfoService,
                configService: configService,
                environmentService: environmentService,
                errorReporter: errorReporter,
                flightRecorder: flightRecorder,
                pasteboardService: pasteboardService,
                systemDevice: MockSystemDevice(),
            ),
            state: AboutState(),
        )
    }

    override func tearDown() {
        super.tearDown()

        coordinator = nil
        configService = nil
        environmentService = nil
        errorReporter = nil
        flightRecorder = nil
        pasteboardService = nil
        subject = nil
    }

    // MARK: Tests

    /// `init` sets the app info.
    @MainActor
    func test_init_loadsValues() {
        subject = AboutProcessor(
            coordinator: coordinator.asAnyCoordinator(),
            services: ServiceContainer.withMocks(
                appInfoService: appInfoService,
                errorReporter: errorReporter,
                systemDevice: MockSystemDevice(),
            ),
            state: AboutState(),
        )

        XCTAssertEqual(
            subject.state.copyrightText,
            "Pass-Y © 2026 aiity\nBased on Bitwarden iOS © Bitwarden Inc. (GPLv3)",
        )
        XCTAssertEqual(subject.state.version, "1.0 (1)")
    }

    /// `perform(_:)` with `.copyVersionInfo` copies the copyright, the version string
    /// and device info to the pasteboard.
    @MainActor
    func test_perform_copyVersionInfo() async {
        await subject.perform(.copyVersionInfo)
        XCTAssertEqual(
            pasteboardService.copyReceivedString,
            """
            Pass-Y © 2026 aiity
            Based on Bitwarden iOS © Bitwarden Inc. (GPLv3)

            📝 Bitwarden 1.0 (1)
            📦 Bundle: com.8bit.bitwarden
            📱 Device: iPhone14,2
            🍏 System: iOS 16.4
            """,
        )
        XCTAssertEqual(subject.state.toast, Toast(title: Localizations.valueHasBeenCopied(Localizations.appInfo)))
    }

    /// `perform(_:)` with `.flightRecorder(.toggleFlightRecorder(true))` navigates to the enable
    /// flight recorder screen when toggled on.
    @MainActor
    func test_perform_flightRecorder_toggleFlightRecorder_on() async {
        XCTAssertNil(subject.state.flightRecorderState.activeLog)

        await subject.perform(.flightRecorder(.toggleFlightRecorder(true)))

        XCTAssertEqual(coordinator.routes, [.flightRecorder(.enableFlightRecorder)])
    }

    /// `perform(_:)` with `.flightRecorder(.toggleFlightRecorder(false))` disables the flight
    /// recorder when toggled off.
    @MainActor
    func test_perform_flightRecorder_toggleFlightRecorder_off() async throws {
        subject.state.flightRecorderState.activeLog = FlightRecorderData.LogMetadata(
            duration: .eightHours,
            startDate: .now,
        )

        await subject.perform(.flightRecorder(.toggleFlightRecorder(false)))

        XCTAssertTrue(flightRecorder.disableFlightRecorderCalled)
    }

    /// `perform(_:)` with `.streamFlightRecorderLog` subscribes to the active flight recorder log.
    @MainActor
    func test_perform_streamFlightRecorderLog() async throws {
        XCTAssertNil(subject.state.flightRecorderState.activeLog)

        let task = Task {
            await subject.perform(.streamFlightRecorderLog)
        }
        defer { task.cancel() }

        let log = FlightRecorderData.LogMetadata(duration: .eightHours, startDate: .now)
        flightRecorder.activeLogSubject.send(log)
        try await waitForAsync { self.subject.state.flightRecorderState.activeLog != nil }
        XCTAssertEqual(subject.state.flightRecorderState.activeLog, log)

        flightRecorder.activeLogSubject.send(nil)
        try await waitForAsync { self.subject.state.flightRecorderState.activeLog == nil }
        XCTAssertNil(subject.state.flightRecorderState.activeLog)
    }

    /// `receive(_:)` with `.clearAppReviewURL` clears the app review URL in the state.
    @MainActor
    func test_receive_clearAppReviewURL() {
        subject.state.appReviewUrl = .example
        subject.receive(.clearAppReviewURL)
        XCTAssertNil(subject.state.appReviewUrl)
    }

    /// `receive(_:)` with `.clearURL` clears the URL in the state.
    @MainActor
    func test_receive_clearURL() {
        subject.state.url = .example
        subject.receive(.clearURL)
        XCTAssertNil(subject.state.url)
    }

    /// `receive(_:)` with action `.flightRecorder(.viewLogsTapped)` navigates to the view flight
    /// recorder logs screen.
    @MainActor
    func test_receive_flightRecorder_viewFlightRecorderLogsTapped() {
        subject.receive(.flightRecorder(.viewLogsTapped))

        XCTAssertEqual(coordinator.routes, [.flightRecorder(.flightRecorderLogs)])
    }

    /// `receive(_:)` with `.helpCenterTapped` opens Pass-Y's support page.
    @MainActor
    func test_receive_helpCenterTapped() {
        subject.receive(.helpCenterTapped)
        XCTAssertEqual(subject.state.url, ExternalLinksConstants.helpAndFeedback)
        XCTAssertEqual(subject.state.url?.absoluteString, "https://github.com/enrzh/pass-y/blob/main/SUPPORT.md")
    }

    /// `receive(_:)` with `.privacyPolicyTapped` opens Pass-Y's privacy policy directly (no alert).
    @MainActor
    func test_receive_privacyPolicyTapped() {
        subject.receive(.privacyPolicyTapped)

        XCTAssertTrue(coordinator.alertShown.isEmpty)
        XCTAssertEqual(subject.state.url, ExternalLinksConstants.privacyPolicy)
        XCTAssertEqual(subject.state.url?.absoluteString, "https://github.com/enrzh/pass-y/blob/main/PRIVACY.md")
    }

    /// `receive(_:)` with `.contactSupportTapped` hands the support mail link to the view.
    @MainActor
    func test_receive_contactSupportTapped() {
        subject.receive(.contactSupportTapped)

        XCTAssertEqual(subject.state.mailURL?.absoluteString, "mailto:support@aiity.de")
        XCTAssertNil(subject.state.url)
    }

    /// `receive(_:)` with `.mailURLOpened(opened: true)` clears the link and copies nothing.
    @MainActor
    func test_receive_mailURLOpened_opened() {
        subject.state.mailURL = ExternalLinksConstants.supportEmail

        subject.receive(.mailURLOpened(opened: true))

        XCTAssertNil(subject.state.mailURL)
        XCTAssertNil(pasteboardService.copyReceivedString)
        XCTAssertNil(subject.state.toast)
    }

    /// `receive(_:)` with `.mailURLOpened(opened: false)` (no mail app) copies the address and says so.
    @MainActor
    func test_receive_mailURLOpened_noMailApp() {
        subject.state.mailURL = ExternalLinksConstants.supportEmail

        subject.receive(.mailURLOpened(opened: false))

        XCTAssertNil(subject.state.mailURL)
        XCTAssertEqual(pasteboardService.copyReceivedString, "support@aiity.de")
        XCTAssertEqual(subject.state.toast, Toast(title: Localizations.noMailAppXCopied("support@aiity.de")))
    }

    /// `receive(_:)` with `.sourceCodeTapped` opens the source code.
    @MainActor
    func test_receive_sourceCodeTapped() {
        subject.receive(.sourceCodeTapped)
        XCTAssertEqual(subject.state.url?.absoluteString, "https://github.com/enrzh/pass-y")
    }

    /// `receive(_:)` with `.licensesTapped` opens the licences screen.
    @MainActor
    func test_receive_licensesTapped() {
        subject.receive(.licensesTapped)
        XCTAssertEqual(coordinator.routes, [.licenses(.overview)])
    }

    /// `receive(_:)` with `.rateTheAppTapped` shows an alert for navigating to the app store.
    /// When `Continue` is tapped on the alert, the `appReviewUrl` is populated.
    @MainActor
    func test_receive_rateTheAppTapped() async throws {
        subject.receive(.rateTheAppTapped)

        let alert = try XCTUnwrap(coordinator.alertShown.last)
        try await alert.tapAction(title: Localizations.continue)
        XCTAssertEqual(
            subject.state.appReviewUrl?.absoluteString,
            "https://github.com/enrzh/pass-y",
        )
    }

    /// `receive(_:)` with `.toastShown` updates the state's toast value.
    @MainActor
    func test_receive_toastShown() {
        let toast = Toast(title: "toast!")
        subject.receive(.toastShown(toast))
        XCTAssertEqual(subject.state.toast, toast)

        subject.receive(.toastShown(nil))
        XCTAssertNil(subject.state.toast)
    }
}
