import BitwardenKit

// MARK: - AboutAction

/// Actions handled by the `AboutProcessor`.
///
enum AboutAction: Equatable {
    /// Clears the app review URL.
    case clearAppReviewURL

    /// The url has been opened so clear the value in the state.
    case clearURL

    /// The contact support button was tapped.
    case contactSupportTapped

    /// An action for the Flight Recorder feature.
    case flightRecorder(FlightRecorderSettingsSectionAction)

    /// The help center button was tapped.
    case helpCenterTapped

    /// The licenses button was tapped.
    case licensesTapped

    /// The mail link was handed to the system.
    ///
    /// - Parameter opened: Whether an app opened it (`false`: no mail app).
    ///
    case mailURLOpened(opened: Bool)

    /// The privacy policy button was tapped.
    case privacyPolicyTapped

    /// The rate the app button was tapped.
    case rateTheAppTapped

    /// The source code button was tapped.
    case sourceCodeTapped

    /// The toast was shown or hidden.
    case toastShown(Toast?)
}
