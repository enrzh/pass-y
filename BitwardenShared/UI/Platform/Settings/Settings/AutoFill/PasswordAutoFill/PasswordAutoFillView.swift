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

    /// An object used to open urls from this view.
    @Environment(\.openURL) private var openURL

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
                VStack(spacing: PassYDesign.Spacing.large) {
                    illustration

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

                steps

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

    /// The illustration: the AutoFill key in a Pass-Y tile (SF Symbols only, no screenshots).
    private var illustration: some View {
        RoundedRectangle(cornerRadius: PassYDesign.Radius.tile(side: 88), style: .continuous)
            .fill(Color.green.gradient)
            .frame(width: 88, height: 88)
            .overlay {
                Image(systemName: "key.viewfinder")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }

    /// The numbered steps to turn on AutoFill in the system settings.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(store.state.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Divider().padding(.leading, 52)
                }
                HStack(alignment: .firstTextBaseline, spacing: PassYDesign.Spacing.medium) {
                    Text(verbatim: "\(index + 1)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentColor))
                        .accessibilityHidden(true)

                    Text(LocalizedStringKey(step))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, PassYDesign.Spacing.large)
                .padding(.vertical, PassYDesign.Spacing.medium)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Localizations.stepXOfY(index + 1, store.state.steps.count))
                .accessibilityValue(Text(LocalizedStringKey(step)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: PassYDesign.Radius.large, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)),
        )
        .accessibilityIdentifier("PasswordAutoFillSteps")
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
