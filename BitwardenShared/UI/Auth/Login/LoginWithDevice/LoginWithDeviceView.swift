import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LoginWithDeviceView

/// A view that allows the user to initiate a login from their device.
///
struct LoginWithDeviceView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<LoginWithDeviceState, LoginWithDeviceAction, LoginWithDeviceEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("iphone.and.arrow.forward", .accentColor),
                    title: store.state.titleText,
                    message: store.state.explanationText,
                )
            }
            .passYPlainListRow()

            fingerprintView

            if store.state.isResendNotificationVisible {
                Section { resendNotificationButton }
            }

            Section {
                allLoginOptionsView
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, PassYDesign.Spacing.small)
            }
            .passYPlainListRow()
        }
        .passYGroupedBackground()
        .navigationBar(title: store.state.navBarText, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
        .task {
            await store.perform(.appeared)
        }
    }

    // MARK: Private Views

    /// The text and button for viewing all login options.
    private var allLoginOptionsView: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: PassYDesign.Spacing.small) { allLoginOptionsContent }
            VStack(spacing: PassYDesign.Spacing.xSmall) { allLoginOptionsContent }
        }
        .font(.subheadline)
    }

    /// The parts of the "need another option" line.
    @ViewBuilder private var allLoginOptionsContent: some View {
        Text(Localizations.needAnotherOption)
            .foregroundStyle(.secondary)

        Button(Localizations.viewAllLoginOptions) {
            store.send(.dismiss)
        }
        .fontWeight(.semibold)
        .buttonStyle(.borderless)
        .accessibilityIdentifier("ViewAllLoginOptionsButton")
    }

    /// The fingerprint phrase title and display.
    private var fingerprintView: some View {
        Section {
            PassYFingerprintPhrase(
                title: Localizations.fingerprintPhrase,
                phrase: store.state.fingerprintPhrase ?? "",
            )
        }
    }

    /// The button to resend the login notification.
    @ViewBuilder private var resendNotificationButton: some View {
        PassYSettingsRow(
            Localizations.resendNotification,
            systemImage: "bell.badge.fill",
            tint: .blue,
            accessory: .none,
            identifier: "ResendNotificationButton",
        ) {
            Task { await store.perform(.resendNotification) }
        }
    }
}

// MARK: - Previews

#Preview {
    LoginWithDeviceView(store: Store(processor: StateProcessor(state: LoginWithDeviceState())))
}
