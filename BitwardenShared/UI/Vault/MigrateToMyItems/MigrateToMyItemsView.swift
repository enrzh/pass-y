import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - MigrateToMyItemsView

/// A view that prompts the user to accept or decline an item transfer request from an organization.
///
struct MigrateToMyItemsView: View {
    // MARK: Properties

    /// An object used to open URLs from this view.
    @Environment(\.openURL) private var openURL

    /// The `Store` for this view.
    @ObservedObject var store: Store<MigrateToMyItemsState, MigrateToMyItemsAction, MigrateToMyItemsEffect>

    // MARK: View

    var body: some View {
        Group {
            switch store.state.page {
            case .transfer:
                transferPage
            case .declineConfirmation:
                declineConfirmationPage
            case .extensionPrompt:
                extensionPromptPage
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: store.state.page)
        .navigationBar(title: Localizations.itemTransfer, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if store.state.page == .declineConfirmation {
                    backToolbarButton {
                        store.send(.backTapped)
                    }
                } else if store.state.isExtension {
                    closeToolbarButton {
                        store.send(.closeTapped)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
        .task {
            await store.perform(.appeared)
        }
    }

    // MARK: Private Views

    /// The "Learn more" link (the transfer ownership help page).
    private var learnMoreLink: some View {
        Text(LocalizedStringKey(Localizations.learnMoreLink(ExternalLinksConstants.transferOwnership)))
            .font(.subheadline.weight(.semibold))
            .accessibilityLinks(in: Localizations.learnMoreLink(ExternalLinksConstants.transferOwnership))
            .frame(maxWidth: .infinity)
    }

    /// The main transfer page prompting the user to accept or decline.
    private var transferPage: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("arrow.left.arrow.right.circle.fill", .blue),
                    title: Localizations.transferItemsToX(store.state.organizationName),
                    message: Localizations.xIsRequiringAllItemsToBeOwnedByTheOrganizationDescriptionLong(
                        store.state.organizationName,
                    ),
                )
                learnMoreLink
            }
            .passYPlainListRow()

            PassYActionStack {
                AsyncButton {
                    await store.perform(.acceptTransferTapped)
                } label: {
                    Text(Localizations.acceptTransfer).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)

                Button(Localizations.declineAndLeave) {
                    store.send(.declineAndLeaveTapped)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    /// The decline confirmation page warning the user about leaving the organization.
    private var declineConfirmationPage: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("exclamationmark.triangle.fill", .orange),
                    title: Localizations.areYouSureYouWantToLeave,
                    message: Localizations.byDecliningYourPersonalItemsWillStayInYourAccountDescriptionLong,
                )
                learnMoreLink
                Text(Localizations.contactYourAdminToRegainAccess)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, PassYDesign.Spacing.large)
            }
            .passYPlainListRow()

            PassYActionStack {
                AsyncButton(role: .destructive) {
                    await store.perform(.leaveOrganizationTapped)
                } label: {
                    Text(Localizations.leaveX(store.state.organizationName)).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.destructive, fillsWidth: true)
            }
        }
    }

    /// The page shown in app extensions prompting the user to complete migration in the main app.
    private var extensionPromptPage: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("arrow.up.forward.app.fill", .blue),
                    title: Localizations.itemTransfer,
                    message: Localizations.itemTransferRequiresMainAppDescriptionLong,
                )
            }
            .passYPlainListRow()

            PassYActionStack {
                Button {
                    openURL(ExternalLinksConstants.appDeepLink)
                    store.send(.continueToBitwardenTapped)
                } label: {
                    Text(Localizations.continueToBitwarden).frame(maxWidth: .infinity)
                }
                .passYButtonStyle(.primary, fillsWidth: true)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Transfer") {
    MigrateToMyItemsView(
        store: Store(
            processor: StateProcessor(
                state: MigrateToMyItemsState(
                    organizationId: "org-123",
                    organizationName: "Acme",
                ),
            ),
        ),
    )
    .navStackWrapped
}

#Preview("Decline Confirmation") {
    MigrateToMyItemsView(
        store: Store(
            processor: StateProcessor(
                state: MigrateToMyItemsState(
                    organizationId: "org-123",
                    organizationName: "Acme",
                    page: .declineConfirmation,
                ),
            ),
        ),
    )
    .navStackWrapped
}
#endif
