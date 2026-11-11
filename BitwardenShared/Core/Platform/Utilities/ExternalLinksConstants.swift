import BitwardenKit
import Foundation

// MARK: - ExternalLinksConstants

/// Links that are used throughout the app.
///
extension ExternalLinksConstants {
    // MARK: Properties

    /// A link to Bitwarden's organizations information webpage.
    static let aboutOrganizations = URL(string: "https://github.com/enrzh/pass-y")!

    /// A deep link to the Bitwarden app.
    static let appDeepLink = URL(string: "bitwarden://")!

    /// A link to the app review page within the app store.
    static let appReview = URL(string: "https://github.com/enrzh/pass-y")

    /// A link to Bitwarden's help page for the integrated authenticator feature.
    static let authenticatorHelp = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to the auto fill help page.
    static let autofillHelp = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for the Fill Assist feature.
    static let fillAssistHelp = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for learning more about the account fingerprint phrase.
    static let fingerprintPhrase = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for generating username types.
    static let generatorUsernameTypes = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to the import logins help page.
    static let importHelp = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for learning more about Premium features.
    static let learnMoreAboutPremium = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to the password options within the passwords section of the settings menu.
    static let passwordOptions = URL(string: "App-prefs:PASSWORDS&path=PASSWORD_OPTIONS")!

    /// A markdown link to Bitwarden's help page about protecting individual items.
    static let protectIndividualItems = URL(
        string: "https://github.com/enrzh/pass-y",
    )!

    /// A link to Bitwarden's product page for Sends.
    static let sendInfo = URL(string: "https://github.com/enrzh/pass-y")!

    /// A markdown link to Bitwarden's terms of service.
    static let termsOfService = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for My vault items migration. .
    static let transferOwnership = URL(string: "https://github.com/enrzh/pass-y")!

    /// A markdown link to Bitwarden's marketing email preferences.
    static let unsubscribeFromMarketingEmails = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for URI match detection.
    static let uriMatchDetections = URL(string: "https://github.com/enrzh/pass-y")!

    /// A link to Bitwarden's help page for showing website icons.
    static let websiteIconsHelp = URL(string: "https://github.com/enrzh/pass-y")!
}
