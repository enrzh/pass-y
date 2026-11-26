import BitwardenKit
import BitwardenResources
import BitwardenSdk
import SwiftUI

// MARK: - ViewPassportItemView

/// The passport details: tap-to-copy rows; passport and national identification numbers masked with eye buttons.
/// No section title.
struct ViewPassportItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<PassportItemState, ViewItemAction, Void>

    var body: some View {
        if !store.state.isPassportDetailsSectionEmpty {
            Section {
                row(Localizations.firstName, store.state.givenName, "PassportFirstNameEntry", .givenName)
                row(Localizations.lastName, store.state.surname, "PassportLastNameEntry", .surname)
                dateRow(Localizations.dateOfBirth, store.state.dateOfBirth, "PassportDateOfBirthEntry")
                row(Localizations.sex, store.state.sex, "PassportSexEntry", nil)
                row(Localizations.birthPlace, store.state.birthPlace, "PassportBirthPlaceEntry", nil)
                row(Localizations.nationality, store.state.nationality, "PassportNationalityEntry", nil)
                secretRow(
                    Localizations.passportNumber,
                    store.state.passportNumber,
                    isVisible: store.state.isPassportNumberVisible,
                    identifier: "PassportNumberEntry",
                    revealIdentifier: "ShowPassportNumberButton",
                    field: .passportNumber,
                ) { .togglePassportNumberVisibilityChanged($0) }
                row(Localizations.passportType, store.state.passportType, "PassportTypeEntry", nil)
                secretRow(
                    Localizations.nationalIdentificationNumber,
                    store.state.nationalIdentificationNumber,
                    isVisible: store.state.isNationalIdentificationNumberVisible,
                    identifier: "PassportNationalIdentificationNumberEntry",
                    revealIdentifier: "ShowPassportNationalIdentificationNumberButton",
                    field: .nationalIdentificationNumber,
                ) { .toggleNationalIdentificationNumberVisibilityChanged($0) }
                row(Localizations.issuingCountry, store.state.issuingCountry, "PassportIssuingCountryEntry", nil)
                row(
                    Localizations.issuingAuthorityOffice,
                    store.state.issuingAuthority,
                    "PassportIssuingAuthorityEntry",
                    nil,
                )
                dateRow(Localizations.issueDate, store.state.issueDate, "PassportIssueDateEntry")
                dateRow(Localizations.expirationDate, store.state.expirationDate, "PassportExpirationDateEntry")
            }
        }
    }

    // MARK: Private Methods

    /// A value row (copies on tap when `field` is set), nothing for an empty value.
    @ViewBuilder
    private func row(_ title: String, _ value: String, _ identifier: String, _ field: CopyableField?) -> some View {
        if !value.isEmpty {
            PassYCopyRow(
                title,
                value: value,
                identifier: identifier,
                copy: field.map { field in { store.send(.copyPressed(value: value, field: field)) } },
            )
        }
    }

    /// A masked row with an eye button that copies on tap, nothing for an empty value.
    @ViewBuilder
    private func secretRow(
        _ title: String,
        _ value: String,
        isVisible: Bool,
        identifier: String,
        revealIdentifier: String,
        field: CopyableField,
        toggle: @escaping (Bool) -> ViewPassportItemAction,
    ) -> some View {
        if !value.isEmpty {
            PassYCopyRow(
                title,
                value: value,
                secret: .init(isRevealed: isVisible, revealIdentifier: revealIdentifier, tintsCharacters: false) {
                    store.send(.passportItemAction(toggle(!isVisible)))
                },
                identifier: identifier,
            ) {
                store.send(.copyPressed(value: value, field: field))
            }
        }
    }

    /// A long date, nothing when unset.
    @ViewBuilder
    private func dateRow(_ title: String, _ value: Date?, _ identifier: String) -> some View {
        if let value {
            PassYCopyRow(title, value: value.longCalendarDateDisplay, identifier: identifier, copy: nil)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Empty View State") {
    NavigationView {
        Form {
            Group {
                ViewPassportItemView(
                    store: Store(
                        processor: StateProcessor(state: PassportItemState()),
                    ),
                )
            }
        }
    }
}

#Preview("Populated View State") {
    NavigationView {
        Form {
            Group {
                ViewPassportItemView(
                    store: Store(
                        processor: StateProcessor(
                            state: PassportItemState(
                                birthPlace: "USA",
                                dateOfBirth: Date(year: 2025, month: 4, day: 20),
                                expirationDate: Date(year: 2026, month: 8, day: 10),
                                givenName: "Mitchell",
                                issueDate: Date(year: 2021, month: 8, day: 10),
                                issuingAuthority: "U.S. Department of State",
                                issuingCountry: "United States",
                                nationalIdentificationNumber: "123456789",
                                nationality: "USA",
                                passportNumber: "X12345678",
                                passportType: "Regular/Tourist",
                                sex: "Male",
                                surname: "Johnson",
                            ),
                        ),
                    ),
                )
            }
        }
    }
}
#endif
