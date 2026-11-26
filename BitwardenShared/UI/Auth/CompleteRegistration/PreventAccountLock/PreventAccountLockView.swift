import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - PreventAccountLockView

/// A view that presents the user with information about how to prevent their account from getting locked.
///
struct PreventAccountLockView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, PreventAccountLockAction, Void>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("lock.shield.fill", .accentColor),
                    title: Localizations.neverLoseAccessToYourVault,
                    message: Localizations
                        .theBestWayToMakeSureYouCanAlwaysAccessYourAccountIsToSetUpSafeguardsFromTheStart,
                )
            }
            .passYPlainListRow()

            Section {
                rowView(
                    systemImage: "lightbulb.fill",
                    tint: .yellow,
                    title: Localizations.createAHint,
                    subtitle: Localizations.yourHintWillBeSentToYouViaEmailWhenYouRequestIt,
                )

                rowView(
                    systemImage: "pencil",
                    tint: .blue,
                    title: Localizations.writeYourPasswordDown,
                    subtitle: Localizations.beCarefulToKeepYourWrittenPasswordSomewhereSecretAndSafe,
                )
            }
        }
        .navigationBar(title: Localizations.preventAccountLockout, titleDisplayMode: .inline)
        .toolbar {
            closeToolbarItem {
                store.send(.dismiss)
            }
        }
    }

    // MARK: Private

    /// A tip row: tinted symbol tile, title and explanation.
    private func rowView(systemImage: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: PassYDesign.Spacing.medium) {
            PassYIconTile(systemImage: systemImage, tint: tint, size: PassYDesign.IconSize.small)

            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .passYListSeparatorLeading()
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    NavigationView {
        PreventAccountLockView(
            store: Store(
                processor: StateProcessor(
                    state: (),
                ),
            ),
        )
    }
}
#endif
