import AuthenticationServices
import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - PasswordAutoFillView

/// A view that shows the instructions for enabling password autofill.
///
struct PasswordAutoFillView: View {
    // MARK: Properties

    /// The store used to render the view.
    @ObservedObject var store: Store<
        PasswordAutoFillState,
        PasswordAutoFillAction,
        PasswordAutoFillEffect,
    >

    /// An object used to determine the current color scheme.
    @Environment(\.colorScheme) var colorScheme

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

    /// An environment variable for getting the vertical size class of the view.
    @Environment(\.verticalSizeClass) var verticalSizeClass

    // MARK: View

    var body: some View {
        Group {
            contentView
        }
        .navigationBar(
            title: store.state.navigationBarTitle,
            titleDisplayMode: .inline,
        )
        .task {
            await store.perform(.checkAutofillOnForeground)
        }
        .onChange(of: store.state.url) { newValue in
            guard let url = newValue else { return }
            openURL(url)
            store.send(.clearURL)
        }
    }

    // MARK: Private Views

    /// The content view.
    private var contentView: some View {
        ScrollView {
            VStack(spacing: PassYDesign.Spacing.xLarge) {
                dynamicStackView {
                    ZStack {
                        gifViewPlaceholder

                        gifView
                    }
                    .frame(width: 230, height: 278)
                    .accessibilityHidden(true)

                    VStack(spacing: PassYDesign.Spacing.medium) {
                        Text(store.state.title)
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)

                        Text(store.state.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, PassYDesign.Spacing.medium)

                Text(
                    LocalizedStringKey(
                        Localizations.needHelpCheckOutAutofillHelp(
                            ExternalLinksConstants.autofillHelp,
                        ),
                    ),
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(spacing: PassYDesign.Spacing.medium) {
                    Button {
                        Task { await store.perform(.continueTapped) }
                    } label: {
                        Text(Localizations.continue).frame(maxWidth: .infinity)
                    }
                    .passYButtonStyle(.primary, fillsWidth: true)

                    if store.state.mode == .onboarding {
                        Button(Localizations.turnOnLater) {
                            Task { await store.perform(.turnAutoFillOnLaterButtonTapped) }
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.horizontal, PassYDesign.Spacing.large)
            .padding(.bottom, PassYDesign.Spacing.xLarge)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .passYGroupedBackground()
    }

    @ViewBuilder private var gifView: some View {
        switch colorScheme {
        case .light:
            GifView(gif: Asset.Images.autofillIosLight)
        case .dark:
            GifView(gif: Asset.Images.autofillIosDark)
        @unknown default:
            GifView(gif: Asset.Images.autofillIosLight)
        }
    }

    /// The placeholder image to present while the gif loads.
    @ViewBuilder private var gifViewPlaceholder: some View {
        switch colorScheme {
        case .light:
            Image(decorative: Asset.Images.autofillIosLightPlaceholder)
                .resizable()
                .scaledToFit()
        case .dark:
            Image(decorative: Asset.Images.autofillIosDarkPlaceholder)
                .resizable()
                .scaledToFit()
        @unknown default:
            Image(decorative: Asset.Images.autofillIosLightPlaceholder)
                .resizable()
                .scaledToFit()
        }
    }

    /// A dynamic stack view that lays out content vertically when in a regular vertical size class
    /// and horizontally for the compact vertical size class.
    @ViewBuilder
    private func dynamicStackView(@ViewBuilder content: () -> some View) -> some View {
        if verticalSizeClass == .regular {
            VStack(spacing: 24, content: content)
        } else {
            HStack(spacing: 24, content: content)
                .padding(.horizontal, 80)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Settings") {
    PasswordAutoFillView(
        store: Store(
            processor: StateProcessor(
                state: .init(
                    mode: .settings,
                ),
            ),
        ),
    )
}

#Preview("Onboarding") {
    PasswordAutoFillView(
        store: Store(
            processor: StateProcessor(
                state: .init(
                    mode: .onboarding,
                ),
            ),
        ),
    )
}
#endif
