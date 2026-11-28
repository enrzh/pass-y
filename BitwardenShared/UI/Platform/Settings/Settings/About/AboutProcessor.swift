// MARK: - AboutProcessor

import BitwardenKit
import BitwardenResources
import Foundation

/// The processor used to manage state and handle actions for the `AboutView`.
///
final class AboutProcessor: StateProcessor<AboutState, AboutAction, AboutEffect> {
    // MARK: Types

    typealias Services = HasAppInfoService
        & HasConfigService
        & HasEnvironmentService
        & HasErrorReporter
        & HasFlightRecorder
        & HasPasteboardService

    // MARK: Properties

    /// The coordinator used to manage navigation.
    private let coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>

    /// The services used by this processor.
    private let services: Services

    // MARK: Initialization

    /// Initializes a new `AboutProcessor`.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator used to manage navigation.
    ///   - services: The services used by this processor.
    ///   - state: The initial state of the processor.
    init(
        coordinator: AnyCoordinator<SettingsRoute, SettingsEvent>,
        services: Services,
        state: AboutState,
    ) {
        self.coordinator = coordinator
        self.services = services

        var state = state
        state.copyrightText = services.appInfoService.copyrightString
        state.version = services.appInfoService.versionString

        super.init(state: state)
    }

    // MARK: Methods

    override func perform(_ effect: AboutEffect) async {
        switch effect {
        case .copyVersionInfo:
            await copyVersionInfo()
        case let .flightRecorder(flightRecorderEffect):
            switch flightRecorderEffect {
            case let .toggleFlightRecorder(isOn):
                if isOn {
                    coordinator.navigate(to: .flightRecorder(.enableFlightRecorder))
                } else {
                    await services.flightRecorder.disableFlightRecorder()
                }
            }
        case .streamFlightRecorderLog:
            await streamFlightRecorderLog()
        }
    }

    override func receive(_ action: AboutAction) {
        switch action {
        case .clearAppReviewURL:
            state.appReviewUrl = nil
        case .clearURL:
            state.url = nil
        case .contactSupportTapped:
            state.mailURL = ExternalLinksConstants.supportEmail
        case let .flightRecorder(flightRecorderAction):
            switch flightRecorderAction {
            case .viewLogsTapped:
                coordinator.navigate(to: .flightRecorder(.flightRecorderLogs))
            }
        case .helpCenterTapped:
            state.url = ExternalLinksConstants.helpAndFeedback
        case .licensesTapped:
            coordinator.navigate(to: .licenses(.overview))
        case let .mailURLOpened(opened):
            state.mailURL = nil
            guard !opened else { return }
            // No mail app: the address goes to the clipboard instead.
            services.pasteboardService.copy(ExternalLinksConstants.supportEmailAddress)
            state.toast = Toast(title: Localizations.noMailAppXCopied(ExternalLinksConstants.supportEmailAddress))
        case .privacyPolicyTapped:
            state.url = ExternalLinksConstants.privacyPolicy
        case .rateTheAppTapped:
            coordinator.showAlert(.appStoreAlert {
                self.state.appReviewUrl = ExternalLinksConstants.appReview
            })
        case .sourceCodeTapped:
            state.url = ExternalLinksConstants.sourceCode
        case let .toastShown(newValue):
            state.toast = newValue
        }
    }

    // MARK: - Private Methods

    /// Copies the app's version info to the pasteboard.
    private func copyVersionInfo() async {
        let appInfo = await services.appInfoService.appInfoString
        services.pasteboardService.copy(appInfo)
        state.toast = Toast(title: Localizations.valueHasBeenCopied(Localizations.appInfo))
    }

    /// Streams the flight recorder's active log metadata.
    private func streamFlightRecorderLog() async {
        for await activeLog in await services.flightRecorder.activeLogPublisher().values {
            state.flightRecorderState.activeLog = activeLog
        }
    }
}
