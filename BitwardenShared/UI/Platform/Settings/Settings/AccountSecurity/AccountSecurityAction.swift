import BitwardenKit
import Foundation

// MARK: AccountSecurityAction

/// Actions handled by the `AccountSecurityProcessor`.
///
enum AccountSecurityAction: Equatable {
    /// Clears the account fingerprint phrase URL after the web app has been opened.
    case clearFingerprintPhraseUrl

    /// Sets the custom session timeout value in seconds.
    case customTimeoutValueSecondsChanged(Int)

    /// The delete account button was pressed.
    case deleteAccountPressed

    /// The logout button was pressed.
    case logout

    /// The manage devices button was tapped.
    case manageDevicesTapped

    /// The session timeout action has changed.
    case sessionTimeoutActionChanged(SessionTimeoutAction)

    /// The session timeout value has changed.
    case sessionTimeoutValueChanged(SessionTimeoutValue)

    /// The user tapped the get started button on the set up unlock action card.
    case showSetUpUnlock

}
