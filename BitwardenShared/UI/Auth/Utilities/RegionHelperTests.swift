import BitwardenKit
import BitwardenKitMocks
import BitwardenResources
import BitwardenSdk
import XCTest

@testable import BitwardenShared

// MARK: - RegionHelperTests

class RegionHelperTests: BitwardenTestCase {
    // MARK: Properties

    var subject: RegionHelper!
    var regionDelegate: MockRegionDelegate!
    var coordinator: MockCoordinator<AuthRoute, AuthEvent>!
    var stateService: MockStateService!

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        coordinator = MockCoordinator<AuthRoute, AuthEvent>()
        stateService = MockStateService()
        regionDelegate = MockRegionDelegate()

        subject = RegionHelper(
            coordinator: coordinator.asAnyCoordinator(),
            delegate: regionDelegate,
            stateService: stateService,
        )
        subject.delegate = regionDelegate
    }

    override func tearDown() {
        super.tearDown()
        subject = nil
    }

    // MARK: Tests

    /// `presentRegionSelectorAlert(title:currentRegion:)` goes straight to the self-hosted settings (Pass-Y has
    /// no cloud regions to pick from).
    @MainActor
    func test_presentRegionSelectorAlert_navigatesToSelfHosted() async {
        await subject.presentRegionSelectorAlert(title: Localizations.creatingOn, currentRegion: .selfHosted)
        XCTAssertTrue(coordinator.alertShown.isEmpty)
        XCTAssertEqual(coordinator.routes.last, .selfHosted(currentRegion: .selfHosted))
    }

    /// `presentRegionSelectorAlert(title:currentRegion:)` with a nil region defaults to self-hosted.
    @MainActor
    func test_presentRegionSelectorAlert_nil() async {
        await subject.presentRegionSelectorAlert(title: Localizations.loggingInOn, currentRegion: nil)
        XCTAssertEqual(coordinator.routes.last, .selfHosted(currentRegion: .selfHosted))
    }

    /// `loadRegion()` with no pre-auth URLs (or the unconfigured placeholder) clears the region instead of
    /// defaulting to a cloud environment.
    func test_loadRegion_nil() async throws {
        stateService.preAuthEnvironmentURLs = nil
        await subject.loadRegion()
        XCTAssertFalse(regionDelegate.setRegionCalled)
        XCTAssertTrue(regionDelegate.clearRegionCalled)
    }

    /// `loadRegion()` with the unconfigured placeholder clears the region.
    func test_loadRegion_unconfigured() async throws {
        stateService.preAuthEnvironmentURLs = .unconfigured
        await subject.loadRegion()
        XCTAssertFalse(regionDelegate.setRegionCalled)
        XCTAssertTrue(regionDelegate.clearRegionCalled)
    }

    /// `loadRegion()` with pre auth region
    func test_loadRegion_us() async throws {
        stateService.preAuthEnvironmentURLs = .defaultUS
        await subject.loadRegion()
        XCTAssertTrue(regionDelegate.setRegionCalled)
        XCTAssertEqual(regionDelegate.setRegionType, .unitedStates)
        XCTAssertEqual(regionDelegate.setRegionUrls, RegionType.unitedStates.defaultURLs)
    }

    /// `loadRegion()` with pre auth region
    func test_loadRegion_eu() async throws {
        stateService.preAuthEnvironmentURLs = .defaultEU
        await subject.loadRegion()
        XCTAssertTrue(regionDelegate.setRegionCalled)
        XCTAssertEqual(regionDelegate.setRegionType, .europe)
        XCTAssertEqual(regionDelegate.setRegionUrls, RegionType.europe.defaultURLs)
    }

    /// `loadRegion()` with pre auth region
    func test_loadRegion_gov() async throws {
        stateService.preAuthEnvironmentURLs = .defaultGov
        await subject.loadRegion()
        XCTAssertTrue(regionDelegate.setRegionCalled)
        XCTAssertEqual(regionDelegate.setRegionType, .gov)
        XCTAssertEqual(regionDelegate.setRegionUrls, RegionType.gov.defaultURLs)
    }

    /// `loadRegion()` with pre auth region
    func test_loadRegion_selfHosted() async throws {
        stateService.preAuthEnvironmentURLs = EnvironmentURLData(base: URL(string: "https://selfhosted.com"))
        await subject.loadRegion()
        XCTAssertTrue(regionDelegate.setRegionCalled)
        XCTAssertEqual(regionDelegate.setRegionType, .selfHosted)
        XCTAssertEqual(regionDelegate.setRegionUrls, EnvironmentURLData(base: URL(string: "https://selfhosted.com")))
    }

    /// `loadRegion()` resolves a `bitwarden.pw` pre-auth environment (including subdomains) to
    /// `.internal` rather than treating it as self-hosted.
    func test_loadRegion_internal() async throws {
        let urls = EnvironmentURLData(base: URL(string: "https://qa-team.sh.bitwarden.pw"))
        stateService.preAuthEnvironmentURLs = urls
        await subject.loadRegion()
        XCTAssertTrue(regionDelegate.setRegionCalled)
        XCTAssertEqual(regionDelegate.setRegionType, .internal)
        XCTAssertEqual(regionDelegate.setRegionUrls, urls)
    }
}

class MockRegionDelegate: RegionDelegate {
    var clearRegionCalled = false
    var setRegionCalled = false
    var setRegionType: RegionType?
    var setRegionUrls: EnvironmentURLData?

    func clearRegion() async {
        clearRegionCalled = true
    }

    func setRegion(_ region: RegionType, _ urls: EnvironmentURLData) async {
        setRegionCalled = true
        setRegionType = region
        setRegionUrls = urls
    }
}
