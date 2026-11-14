import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ImportLoginsSuccessView

/// A view that informs the user that importing logins was successful.
///
struct ImportLoginsSuccessView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, Void, ImportLoginsSuccessEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text(Localizations.importSuccessful)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(Localizations.manageYourLoginsFromAnywhereWithBitwardenToolsForWebAndDesktop)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                rowView(
                    symbol: "puzzlepiece.extension",
                    title: Localizations.downloadTheBrowserExtension,
                    subtitle: Localizations
                        .goToBitwardenToIntegrateBitwardenIntoYourFavoriteBrowserForASeamlessExperience,
                )
                rowView(
                    symbol: "desktopcomputer",
                    title: Localizations.useTheWebApp,
                    subtitle: Localizations.logInAtBitwardenToEasilyManageYourAccountAndUpdateSettings,
                )
                rowView(
                    symbol: "checkmark.shield",
                    title: Localizations.autofillPasswords,
                    subtitle: Localizations.setUpAutofillOnAllYourDevicesToLoginWithASingleTapAnywhere,
                )
            }

            Section {
                AsyncButton {
                    await store.perform(.dismiss)
                } label: {
                    Text(Localizations.gotIt).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .passYNativeFormBackground()
        .navigationBar(title: Localizations.bitwardenTools, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                closeToolbarButton {
                    Task {
                        await store.perform(.dismiss)
                    }
                }
            }
        }
    }

    // MARK: Private

    /// A row with a leading SF Symbol, title and subtitle.
    private func rowView(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ImportLoginsSuccessView(store: Store(processor: StateProcessor()))
        .navStackWrapped
}
#endif
