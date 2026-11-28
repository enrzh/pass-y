import BitwardenKit
import Foundation

// MARK: - ExternalLinksConstants

/// Links that are used throughout the app.
///
extension ExternalLinksConstants {
    // MARK: Properties

    /// A link to Pass-Y's organizations information webpage.
    static let aboutOrganizations = support("organizations")

    /// A deep link to the Bitwarden app.
    static let appDeepLink = URL(string: "bitwarden://")!

    /// A link to the app review page within the app store.
    static let appReview = URL(string: "https://github.com/enrzh/pass-y")

    /// A link to Pass-Y's help page for the integrated authenticator feature.
    static let authenticatorHelp = support("verification-codes")

    /// A link to the auto fill help page.
    static let autofillHelp = support("autofill")

    /// A link to Pass-Y's help page for the Fill Assist feature.
    static let fillAssistHelp = support("fill-assist")

    /// A link to Pass-Y's help page for learning more about the account fingerprint phrase.
    static let fingerprintPhrase = support("fingerprint-phrase")

    /// A link to Pass-Y's help page for generating username types.
    static let generatorUsernameTypes = support("username-generator")

    /// A link to the import logins help page.
    static let importHelp = support("importing-passwords")

    /// A link to Pass-Y's help page for learning more about Premium features.
    static let learnMoreAboutPremium = support("premium-features")

    /// A link to the password options within the passwords section of the settings menu.
    static let passwordOptions = URL(string: "App-prefs:PASSWORDS&path=PASSWORD_OPTIONS")!

    /// A markdown link to Pass-Y's help page about protecting individual items.
    static let protectIndividualItems = support("master-password-re-prompt")

    /// A link to Pass-Y's product page for Sends.
    static let sendInfo = support("send")

    /// A markdown link to Pass-Y's terms of service.
    static let termsOfService = support("terms")

    /// A link to Pass-Y's help page for My vault items migration. .
    static let transferOwnership = support("organizations")

    /// A markdown link to Pass-Y's marketing email preferences.
    static let unsubscribeFromMarketingEmails = support("emails")

    /// A link to Pass-Y's help page for URI match detection.
    static let uriMatchDetections = support("uri-match-detection")

    /// A link to Pass-Y's help page for showing website icons.
    static let websiteIconsHelp = support("website-icons")
}
