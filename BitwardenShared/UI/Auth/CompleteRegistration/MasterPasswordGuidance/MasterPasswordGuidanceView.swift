import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - MasterPasswordGuidanceView

/// A view that presents the user with guidance about how to create a strong master password.
///
struct MasterPasswordGuidanceView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<Void, MasterPasswordGuidanceAction, Void>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYHeroHeader(
                    mark: .symbol("key.fill", .accentColor),
                    title: Localizations.aSecureMemorablePassword,
                    message: Localizations.aSecureMemorablePasswordDescriptionLong,
                )
            }
            .passYPlainListRow()

            Section {
                numberedRowView(1, title: Localizations.chooseThreeOrFourRandomWords,
                                subtitle: Localizations.chooseThreeOrFourRandomWordsDescriptionLong)
                numberedRowView(2, title: Localizations.combineThoseWordsTogether,
                                subtitle: Localizations.combineThoseWordsTogetherDescriptionLong)
                numberedRowView(3, title: Localizations.makeItYours,
                                subtitle: Localizations.makeItYoursDescriptionLong)
            }

            Section {
                PassYSettingsRow(
                    Localizations.checkOutThePassphraseGenerator,
                    systemImage: "wand.and.stars",
                    tint: .purple,
                ) {
                    store.send(.generatePasswordPressed)
                }
            } header: {
                Text(Localizations.needSomeInspiration)
            }
        }
        .navigationBar(title: Localizations.masterPasswordHelp, titleDisplayMode: .inline)
        .toolbar {
            closeToolbarItem {
                store.send(.dismiss)
            }
        }
    }

    // MARK: Private Views

    /// A numbered step: the number in a tinted tile, the title and the explanation.
    private func numberedRowView(_ number: Int, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: PassYDesign.Spacing.medium) {
            PassYIconTile(systemImage: "\(number).circle.fill", tint: .accentColor, size: PassYDesign.IconSize.small)

            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                Text(LocalizedStringKey(title))
                    .font(.body.weight(.semibold))
                Text(LocalizedStringKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .passYListSeparatorLeading()
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    MasterPasswordGuidanceView(store: Store(processor: StateProcessor())).navStackWrapped
}
#endif
