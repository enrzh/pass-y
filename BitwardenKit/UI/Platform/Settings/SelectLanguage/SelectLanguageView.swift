import BitwardenResources
import SwiftUI

// MARK: - SelectLanguageView

/// A view that shows a list of all the available languages to select from.
///
public struct SelectLanguageView: View {
    // MARK: Properties

    /// The `Store` for this view.
    @ObservedObject var store: Store<SelectLanguageState, SelectLanguageAction, Void>

    // MARK: View

    public var body: some View {
        List {
            Section {
                ForEach(LanguageOption.allCases) { languageOption in
                    languageOptionRow(languageOption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBar(title: Localizations.selectLanguage, titleDisplayMode: .inline)
        .toolbar {
            cancelToolbarItem {
                store.send(.dismiss)
            }
        }
    }

    // MARK: Initializer

    /// Initializes a `SelectLanguageView`.
    ///
    /// - Parameters:
    ///   - store: The `Store` for this view.
    ///
    public init(store: Store<SelectLanguageState, SelectLanguageAction, Void>) {
        self.store = store
    }

    // MARK: Private Views

    /// Construct the row for the language option: the name, a checkmark on the current language.
    private func languageOptionRow(_ languageOption: LanguageOption) -> some View {
        let isSelected = languageOption == store.state.currentLanguage
        return Button {
            store.send(.languageTapped(languageOption))
        } label: {
            HStack {
                Text(languageOption.title)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Previews

#Preview {
    SelectLanguageView(store: Store(processor: StateProcessor(state: SelectLanguageState())))
}
