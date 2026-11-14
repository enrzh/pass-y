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
                Button {
                    store.send(.languageTapped)
                } label: {
                    HStack {
                        Text(Localizations.language).foregroundStyle(.primary)
                        Spacer()
                        Text(store.state.currentLanguage.title).foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } footer: {
                Text(Localizations.languageChangeRequiresAppRestart)
            }

            Section {
                Picker(
                    Localizations.theme,
                    selection: store.binding(
                        get: \.appTheme,
                        send: AppearanceAction.appThemeChanged,
                    ),
                ) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.localizedName).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("ThemeChooser")
            } footer: {
                Text(Localizations.themeDescription)
            }

            Section {
                Toggle(
                    isOn: store.binding(
                        get: \.isShowWebsiteIconsToggleOn,
                        send: AppearanceAction.toggleShowWebsiteIcons,
                    ),
                ) {
                    HStack(spacing: 8) {
                        Text(Localizations.showWebsiteIcons)
                        Button {
                            openURL(ExternalLinksConstants.websiteIconsHelp)
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.footnote)
                                .accessibilityLabel(Localizations.learnMore)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("ShowWebsiteIconsSwitch")
                .accessibilityLabel(Localizations.showWebsiteIcons)
            } footer: {
                Text(Localizations.showWebsiteIconsDescription)
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
