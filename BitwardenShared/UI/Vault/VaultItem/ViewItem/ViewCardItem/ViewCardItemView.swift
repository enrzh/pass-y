import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ViewCardItemView

/// The card details of a card item: cardholder, number and security code (masked, eye button, tap copies), brand
/// and expiry. No section title.
struct ViewCardItemView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<any ViewCardItemState, ViewItemAction, ViewItemEffect>

    var body: some View {
        if !store.state.isCardDetailsSectionEmpty {
            Section {
                cardholderNameItem

                cardNumberItem

                brandItem

                expirationItems

                securityCodeItem
            }
        }
    }

    @ViewBuilder private var cardholderNameItem: some View {
        if !store.state.cardholderName.isEmpty {
            PassYCopyRow(
                Localizations.cardholderName,
                value: store.state.cardholderName,
                identifier: "CardholderNameEntry",
                copy: nil,
            )
        }
    }

    @ViewBuilder private var cardNumberItem: some View {
        let number = store.state.cardNumber
        let isVisible: Bool = store.state.isNumberVisible
        if !number.isEmpty {
            PassYCopyRow(
                Localizations.number,
                value: store.state.formattedCardNumber,
                secret: .init(isRevealed: isVisible, revealIdentifier: "ShowCardNumberButton", tintsCharacters: false) {
                    store.send(.cardItemAction(.toggleNumberVisibilityChanged(!isVisible)))
                },
                identifier: "CardNumberEntry",
            ) {
                store.send(.copyPressed(value: number, field: .cardNumber))
            }
        }
    }

    @ViewBuilder private var brandItem: some View {
        if case .custom = store.state.brand {
            PassYCopyRow(Localizations.brand, value: store.state.brandName, identifier: "CardBrandEntry", copy: nil)
                .accessibilityIdentifier("ItemRow")
        }
    }

    @ViewBuilder private var expirationItems: some View {
        let expirationString = store.state.expirationString
        if !expirationString.isEmpty {
            PassYCopyRow(
                Localizations.expiration,
                value: expirationString,
                identifier: "CardExpirationYearEntry",
                copy: nil,
            )
        }
    }

    @ViewBuilder private var securityCodeItem: some View {
        let code = store.state.cardSecurityCode
        let isVisible: Bool = store.state.isCodeVisible
        if !code.isEmpty {
            PassYCopyRow(
                Localizations.securityCode,
                value: code,
                secret: .init(
                    isRevealed: isVisible,
                    revealIdentifier: "CardShowSecurityCodeButton",
                    tintsCharacters: false,
                ) {
                    store.send(.cardItemAction(.toggleCodeVisibilityChanged(!isVisible)))
                },
                identifier: "CardSecurityCodeEntry",
            ) {
                store.send(.copyPressed(value: code, field: .securityCode))
            }
        }
    }
}

#if DEBUG
#Preview("Card") {
    Form {
        ViewCardItemView(
            store: Store(
                processor: StateProcessor(
                    state: {
                        var state = CardItemState()
                        state.brand = .custom(.visa)
                        state.cardNumber = "4400123456789"
                        state.cardSecurityCode = "123"
                        state.cardholderName = "Bitwarden User"
                        state.expirationMonth = .custom(.aug)
                        state.expirationYear = "1989"
                        state.isNumberVisible = true
                        return state
                    }() as (any ViewCardItemState),
                ),
            ),
        )
    }
}
#endif
