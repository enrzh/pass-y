import BitwardenKit
import BitwardenSdk
import Foundation

@testable import BitwardenShared

extension StartRegistrationState {
    static func fixture(
        emailText: String = "example@email.com",
        isReceiveMarketingToggleOn: Bool = true,
        nameText: String = "name",
        region: RegionType = .unitedStates,
        serverHost: String? = "vault.example.com",
    ) -> Self {
        var state = StartRegistrationState(
            emailText: emailText,
            isReceiveMarketingToggleOn: isReceiveMarketingToggleOn,
            nameText: nameText,
            region: region,
        )
        state.serverHost = serverHost
        return state
    }
}
