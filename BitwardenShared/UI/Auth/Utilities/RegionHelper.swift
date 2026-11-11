import BitwardenKit
import BitwardenResources
import Foundation

// MARK: - RegionHelper

/// Helper class with common functionality related to the region selector.
///
class RegionHelper {
    /// Used to perform navigations and showing alert
    let coordinator: AnyCoordinator<AuthRoute, AuthEvent>

    /// Service used to get environment information
    let stateService: StateService

    /// The delegate for the processor that is notified when the user saves their environment settings.
    weak var delegate: RegionDelegate?

    // MARK: Initialization

    /// Creates a new `RegionHelper`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator that handles navigation.
    ///   - delegate: The delegate for the processor.
    ///   - stateService: The services used by the helper .
    ///
    init(coordinator: AnyCoordinator<AuthRoute, AuthEvent>,
         delegate: RegionDelegate,
         stateService: StateService) {
        self.coordinator = coordinator
        self.delegate = delegate
        self.stateService = stateService
    }

    /// Builds an alert for region selection and navigates to the alert.
    ///
    /// - Parameters:
    ///   - title: The title of the alert.
    ///   - currentRegion: The currently selected region.
    ///   - excludingRegions: Regions to omit from the picker. Defaults to empty (all selectable regions shown).
    ///
    func presentRegionSelectorAlert(
        title: String,
        currentRegion: RegionType?,
        excludingRegions: [RegionType] = [],
    ) async {
        // Pass-Y only supports self-hosted (Vaultwarden) servers, so go straight to the server settings.
        await coordinator.navigate(
            to: .selfHosted(currentRegion: currentRegion ?? .selfHosted),
            context: delegate,
        )
    }

    /// Sets the region to the last used region.
    ///
    func loadRegion() async {
        guard let urls = await stateService.getPreAuthEnvironmentURLs(), !urls.isUnconfigured else {
            await delegate?.clearRegion()
            return
        }

        await delegate?.setRegion(urls.region, urls)
    }
}

// MARK: - RegionDelegate

/// A delegate of `Region` that is notified when the user saves their environment settings.
///
protocol RegionDelegate: AnyObject {
    /// Sets the region and the URLs to use.
    ///
    /// - Parameters:
    ///   - region: The region to use.
    ///   - urls: The URLs that the app should use for the region.
    ///
    func setRegion(_ region: RegionType, _ urls: EnvironmentURLData) async

    /// Called when no server has been configured yet.
    func clearRegion() async
}

extension RegionDelegate {
    func clearRegion() async {}
}
