import Foundation

// MARK: - ExternalLinksConstants

/// Links that are used throughout the apps.
///
public enum ExternalLinksConstants {
    // MARK: Properties

    /// Pass-Y's help page for the Flight Recorder.
    public static let flightRecorderHelp = support("flight-recorder")

    /// Pass-Y's help and support page.
    public static let helpAndFeedback = URL(string: "https://github.com/enrzh/pass-y/blob/main/SUPPORT.md")!

    /// Pass-Y's privacy policy.
    public static let privacyPolicy = URL(string: "https://github.com/enrzh/pass-y/blob/main/PRIVACY.md")!

    /// The source code of Pass-Y.
    public static let sourceCode = URL(string: "https://github.com/enrzh/pass-y")!

    /// The support email address of Pass-Y.
    public static let supportEmailAddress = "support@aiity.de"

    /// A link that writes an email to Pass-Y support.
    public static let supportEmail = URL(string: "mailto:\(supportEmailAddress)")!

    // MARK: Methods

    /// A section of Pass-Y's help and support page.
    ///
    /// - Parameter anchor: The anchor of the section heading (GitHub's heading anchor).
    /// - Returns: The link to the section.
    ///
    public static func support(_ anchor: String) -> URL {
        URL(string: "\(helpAndFeedback.absoluteString)#\(anchor)")!
    }
}
