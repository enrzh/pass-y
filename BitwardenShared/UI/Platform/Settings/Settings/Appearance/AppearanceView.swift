import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - AppearanceView

/// A view for configuring appearance settings.
///
struct AppearanceView: View {
    // MARK: Properties

    /// An action that opens URLs.
    @Environment(\.openURL) private var openURL

    /// The store used to render the view.
    @ObservedObject var store: Store<AppearanceState, AppearanceAction, AppearanceEffect>

    // MARK: View

    var body: some View {
        Form {
            Section {
                PassYSettingsRow(
                    Localizations.language,
                    systemImage: "globe",
                    tint: .blue,
                    value: store.state.currentLanguage.title,
                    identifier: "LanguageChooser",
                ) {
                    store.send(.languageTapped)
                }
            } footer: {
                PassYFooterText(Localizations.languageChangeRequiresAppRestart)
            }

            Section {
                Picker(
                    selection: store.binding(
                        get: \.appTheme,
                        send: AppearanceAction.appThemeChanged,
                    ),
                ) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                } label: {
                    PassYSettingsRowLabel(title: Localizations.theme, systemImage: "circle.lefthalf.filled", tint: .indigo)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ThemeChooser")
            } footer: {
                PassYFooterText(Localizations.themeDescription)
            }

            Section {
                PassYToggleRow(
                    Localizations.showWebsiteIcons,
                    systemImage: "photo.on.rectangle.angled",
                    tint: .teal,
                    isOn: store.binding(
                        get: \.isShowWebsiteIconsToggleOn,
                        send: AppearanceAction.toggleShowWebsiteIcons,
                    ),
                    identifier: "ShowWebsiteIconsSwitch",
                )
            } footer: {
                PassYFooterText(Localizations.showWebsiteIconsDescription, link: Localizations.learnMore) {
                    openURL(ExternalLinksConstants.websiteIconsHelp)
                }
            }
        }
        .navigationBar(title: Localizations.appearance, titleDisplayMode: .inline)
        .task {
            await store.perform(.loadData)
        }
    }
}

// MARK: Previews

#Preview {
    AppearanceView(store: Store(processor: StateProcessor(state: AppearanceState())))
}
