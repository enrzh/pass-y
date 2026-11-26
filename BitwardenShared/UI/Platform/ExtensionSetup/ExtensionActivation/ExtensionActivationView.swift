import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ExtensionActivationView

/// A view that confirms the user enabled and set up an app extension.
///
struct ExtensionActivationView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<
        ExtensionActivationState,
        ExtensionActivationAction,
        ExtensionActivationEffect,
    >

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    // MARK: View

    var body: some View {
        Form {
            if store.state.showLegacyView {
                legacyContent
            } else {
                content
            }
        }
        .navigationTitle(store.state.navigationBarTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            cancelToolbarItem(hidden: !store.state.showLegacyView) {
                store.send(.cancelTapped)
            }
        }
        .task {
            await store.perform(.appeared)
        }
    }

    // MARK: Private Views

    /// The main content of the view.
    @ViewBuilder private var content: some View {
        Section {
            PassYHeroHeader(
                mark: .symbol("checkmark.circle.fill", .green),
                title: Localizations.youreAllSet,
                message: Localizations.autoFillActivatedDescriptionLong,
            )
            .padding(.top, PassYDesign.Spacing.xLarge)
        }
        .passYPlainListRow()

        PassYActionStack {
            Button {
                openURL(ExternalLinksConstants.appDeepLink)
            } label: {
                Text(Localizations.continueToBitwarden).frame(maxWidth: .infinity)
            }
            .passYButtonStyle(.primary, fillsWidth: true)

            Button(Localizations.backToSettings) {
                store.send(.cancelTapped)
            }
            .buttonStyle(.borderless)
        }
    }

    /// The legacy view for this screen kept intact to support both versions.
    @ViewBuilder private var legacyContent: some View {
        Section {
            PassYHeroHeader(
                mark: store.state.extensionType == .appExtension
                    ? .shield
                    : .symbol("checkmark.circle.fill", .green),
                title: store.state.title,
                message: store.state.message,
            )
            .padding(.top, PassYDesign.Spacing.xLarge)
        }
        .passYPlainListRow()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Autofill Extension") {
    NavigationView {
        ExtensionActivationView(
            store: Store(
                processor: StateProcessor(
                    state: ExtensionActivationState(
                        extensionType: .autofillExtension,
                    ),
                ),
            ),
        )
    }
}

#Preview("App Extension") {
    NavigationView {
        ExtensionActivationView(
            store: Store(
                processor: StateProcessor(
                    state: ExtensionActivationState(
                        extensionType: .appExtension,
                    ),
                ),
            ),
        )
    }
}
#endif
