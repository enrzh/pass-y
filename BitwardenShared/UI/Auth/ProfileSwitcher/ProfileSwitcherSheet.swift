import BitwardenKit
import BitwardenResources
import SwiftUI

public struct ProfileSwitcherSheet: View {
    /// The `Store` for this view.
    @ObservedObject var store: Store<ProfileSwitcherState, ProfileSwitcherAction, ProfileSwitcherEffect>

    public var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                PassYSectionHeader(Localizations.selectAccount)
                    .padding(.horizontal, PassYDesign.Spacing.large)
                ProfileSwitcherAccountsView(store: store)
                    .clipShape(RoundedRectangle(cornerRadius: PassYDesign.Radius.large, style: .continuous))
                if store.state.showsAddAccount {
                    addAccountRow
                        .padding(.top, PassYDesign.Spacing.small)
                }
            }
            .padding(.horizontal, PassYDesign.Spacing.large)
        }
        .navigationBar(title: Localizations.accounts, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                closeToolbarButton {
                    store.send(.dismissTapped)
                }
            }
        }
        .task {
            await store.perform(.refreshAccountProfiles)
        }
        .scrollView()
    }

    // MARK: Private Properties

    /// A row to add an account
    @ViewBuilder private var addAccountRow: some View {
        Button {
            Task { await store.perform(.addAccountPressed) }
        } label: {
            Label(Localizations.addAccount, systemImage: "plus")
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("AddAccountButton")
    }
}

// MARK: Previews

#if DEBUG
#Preview("Single Account") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NavigationView {
                ProfileSwitcherSheet(
                    store: Store(
                        processor: StateProcessor(
                            state: .singleAccount,
                        ),
                    ),
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Dual Account") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NavigationView {
                ProfileSwitcherSheet(
                    store: Store(
                        processor: StateProcessor(
                            state: .dualAccounts,
                        ),
                    ),
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Many Accounts") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NavigationView {
                ProfileSwitcherSheet(
                    store: Store(
                        processor: StateProcessor(
                            state: .subMaximumAccounts,
                        ),
                    ),
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}

#Preview("Max Accounts") {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            NavigationView {
                ProfileSwitcherSheet(
                    store: Store(
                        processor: StateProcessor(
                            state: .maximumAccounts,
                        ),
                    ),
                )
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
}
#endif
