import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LoginRequestView

/// A view that shows the information of the login request to allow the user to confirm or deny the request.
///
struct LoginRequestView: View {
    // MARK: Static Properties

    /// The formatter used to display the relative time of the login request.
    private static let relativeDateTimeFormatter = RelativeDateTimeFormatter()

    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<LoginRequestState, LoginRequestAction, LoginRequestEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("person.badge.key.fill", .accentColor),
                    title: Localizations.areYouTryingToLogIn,
                    message: Localizations.logInAttemptByXOnY(
                        store.state.email ?? "",
                        store.state.request.origin,
                    ),
                )
                .accessibilityIdentifier("LogInAttemptByLabel")
            }
            .passYPlainListRow()

            Section {
                PassYFingerprintPhrase(
                    title: Localizations.fingerprintPhrase,
                    phrase: store.state.request.fingerprintPhrase ?? "",
                )
            }

            Section {
                PassYValueRow(
                    Localizations.deviceType,
                    value: store.state.request.requestDeviceType,
                    identifier: "DeviceTypeValueLabel",
                )
                PassYValueRow(Localizations.ipAddress, value: store.state.request.requestIpAddress)
                PassYValueRow(
                    Localizations.time,
                    value: Self.relativeDateTimeFormatter.localizedString(
                        for: store.state.request.creationDate,
                        relativeTo: Date(),
                    ),
                )
            }

            Section {
                VStack(spacing: PassYDesign.Spacing.medium) {
                    confirmButton
                    denyButton
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
            }
            .passYPlainListRow()
        }
        .refreshable { [weak store] in
            await store?.perform(.reloadData)
        }
        .navigationBar(title: Localizations.logInRequested, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.loadData)
        }
    }

    // MARK: Private Views

    /// The confirm login button (the primary action).
    private var confirmButton: some View {
        Button {
            Task { await store.perform(.answerRequest(approve: true)) }
        } label: {
            Text(Localizations.confirmLogIn).frame(maxWidth: .infinity)
        }
        .passYButtonStyle(.primary, fillsWidth: true)
        .accessibilityIdentifier("ConfirmLoginButton")
    }

    /// The deny login button.
    private var denyButton: some View {
        Button(role: .destructive) {
            Task { await store.perform(.answerRequest(approve: false)) }
        } label: {
            Text(Localizations.denyLogIn).frame(maxWidth: .infinity)
        }
        .passYButtonStyle(.destructive, fillsWidth: true)
        .accessibilityIdentifier("DenyLoginButton")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    LoginRequestView(store: Store(processor: StateProcessor(state: LoginRequestState(
        request: .fixture(
            creationDate: .now,
            fingerprintPhrase: "which-ninja-turtle-is-the-best",
        ),
    ))))
}
#endif
