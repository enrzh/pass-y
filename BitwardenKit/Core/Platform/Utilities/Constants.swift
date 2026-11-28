import Foundation

/// A type alias for the client type.
public typealias ClientType = String

// MARK: - Constants

/// Constant values reused throughout the app.
///
public enum Constants {
    /// The client type corresponding to the app.
    public static let clientType: ClientType = "mobile"

    /// The upstream Bitwarden mobile version this app is compatible with, sent to the server as the client version.
    /// Servers gate features by it (Vaultwarden withholds SSH keys below 2024.12.0), so Pass-Y's own marketing
    /// version must not be sent. Raise it when upstream changes are merged.
    public static let serverCompatibilityVersion = "2026.9.1"

    /// The device type for this app.
    public static let deviceType: DeviceType = .iOS

    /// The number of days that a flight recorder log will remain on the device after the end date
    /// before being automatically deleted.
    static let flightRecorderLogExpirationDays = 30

    /// The minimum number of minutes before attempting a server config sync again.
    public static let minimumConfigSyncInterval: TimeInterval = 60 * 60 // 60 minutes

    /// The number of seconds remaining on a TOTP code at which the next code
    /// preview becomes visible, if enabled.
    public static let nextTOTPCodePreviewThreshold = 10

    /// The search debounce time in nanoseconds.
    public static let searchDebounceTimeInNS: UInt64 = 200_000_000 // 200ms

    /// The number of seconds remaining on a TOTP code at which the countdown
    /// circle transitions from its normal color to the urgent color.
    public static let totpUrgentCountdownThreshold = 7

    /// The default file name when the file name cannot be determined.
    public static let unknownFileName = "unknown_file_name"
}
