import BitwardenResources
import XCTest

@testable import BitwardenShared

// MARK: - PasswordAutoFillStateTests

class PasswordAutoFillStateTests: BitwardenTestCase {
    // MARK: Tests

    /// `navigationBarTitle` returns the account setup title when in onboarding mode.
    func test_navigationBarTitle_onboarding() {
        let subject = PasswordAutoFillState(mode: .onboarding)
        XCTAssertEqual(subject.navigationBarTitle, Localizations.accountSetup)
    }

    /// `navigationBarTitle` returns the password autofill title when in settings mode.
    func test_navigationBarTitle_settings() {
        let subject = PasswordAutoFillState(mode: .settings)
        XCTAssertEqual(subject.navigationBarTitle, Localizations.passwordAutofill)
    }

    /// `title` returns the "Autofill with Bitwarden" title.
    func test_title_iOS18Plus() {
        let subject = PasswordAutoFillState(mode: .onboarding)
        XCTAssertEqual(subject.title, Localizations.autofillWithBitwarden)
    }

    /// `subtitle` returns the "Autofill with Bitwarden" description.
    func test_subtitle_iOS18Plus() {
        let subject = PasswordAutoFillState(mode: .onboarding)
        XCTAssertEqual(subject.subtitle, Localizations.autofillWithBitwardenDescriptionLong)
    }
}
