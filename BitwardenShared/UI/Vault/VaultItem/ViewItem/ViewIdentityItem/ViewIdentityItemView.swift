import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewIdentityItemView

/// The fields of an identity item in three cards without titles (Contacts style): personal details, identification
/// (the social security number masked with an eye button), contact info. Every row copies on tap.
struct ViewIdentityItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<IdentityItemState, ViewItemAction, Void>

    var body: some View {
        personalDetailsSection

        identificationSection

        contactInfoSection
    }

    /// The identity's personal details.
    @ViewBuilder var personalDetailsSection: some View {
        if !store.state.isPersonalDetailsSectionEmpty {
            Section {
                row(Localizations.identityName, store.state.identityName, "ItemNameEntry", .identityName)
                row(Localizations.username, store.state.userName, "IdentityUsernameEntry", .username)
                row(Localizations.company, store.state.company, "IdentityCompanyEntry", .company)
            }
        }
    }

    /// The identity's identification details.
    @ViewBuilder var identificationSection: some View {
        if !store.state.isIdentificationSectionEmpty {
            Section {
                if !store.state.socialSecurityNumber.isEmpty {
                    let socialSecurityNumber = store.state.socialSecurityNumber
                    PassYCopyRow(
                        Localizations.ssn,
                        value: socialSecurityNumber,
                        secret: .init(
                            isRevealed: store.state.showSocialSecurityNumber,
                            revealIdentifier: "ShowIdentitySsnButton",
                            tintsCharacters: false,
                        ) {
                            store.send(.ssnVisibilityPressed)
                        },
                        identifier: "IdentitySsnEntry",
                    ) {
                        store.send(.copyPressed(value: socialSecurityNumber, field: .socialSecurityNumber))
                    }
                }
                row(Localizations.passportNumber, store.state.passportNumber, "IdentityPassportNumberEntry", .passportNumber)
                row(Localizations.licenseNumber, store.state.licenseNumber, "IdentityLicenseNumberEntry", .licenseNumber)
            }
        }
    }

    /// The identity's contact info.
    @ViewBuilder var contactInfoSection: some View {
        if !store.state.isContactInfoSectionEmpty {
            Section {
                row(Localizations.email, store.state.email, "IdentityEmailEntry", .email)
                row(Localizations.phone, store.state.phone, "IdentityPhoneEntry", .phone)
                row(Localizations.address, store.state.fullAddress, "IdentityAddressOneEntry", .fullAddress, layout: .stacked)
            }
        }
    }

    /// A tap-to-copy row, nothing for an empty value.
    @ViewBuilder
    private func row(
        _ title: String,
        _ value: String,
        _ identifier: String,
        _ field: CopyableField,
        layout: PassYCopyRow<EmptyView, EmptyView>.Layout = .inline,
    ) -> some View {
        if !value.isEmpty {
            PassYCopyRow(title, value: value, identifier: identifier, layout: layout) {
                store.send(.copyPressed(value: value, field: field))
            }
        }
    }
}

#if DEBUG
#Preview("Identity") {
    Form {
        ViewIdentityItemView(
            store: Store(
                processor: StateProcessor(
                    state: IdentityItemState(
                        title: .custom(.dr),
                        firstName: "First",
                        lastName: "last",
                        middleName: "middle",
                        userName: "user name",
                        socialSecurityNumber: "12-34-1234",
                        address1: "address line 1",
                        address2: "address line 2",
                        address3: "address line 3",
                        cityOrTown: "City",
                        state: "State",
                        postalCode: "123",
                        country: "USA",
                    ),
                ),
            ),
        )
    }
}
#endif
