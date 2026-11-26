import BitwardenKit
import SwiftUI

// MARK: - PassYPickerRow

/// A choice row of a Pass-Y form: the title on the left, the current choice and the up/down chevrons on the right in
/// the tint colour (the look of a native menu `Picker` in a `Form`). Tapping opens a menu with the options, a checkmark
/// on the current one and optional extra actions below a divider (e.g. "Add folder"). Options are any hashable values
/// with a name; `Menuable` options (folders, owners, card brands, months, deletion dates ...) need no name closure.
///
/// ```swift
/// PassYPickerRow(Localizations.folder, options: folders, selection: $folder, identifier: "FolderPicker") {
///     Button(Localizations.addFolder) { addFolder() }
/// }
/// ```
///
struct PassYPickerRow<Option: Hashable, Actions: View>: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The options.
    let options: [Option]

    /// The current option.
    @Binding var selection: Option

    /// The accessibility identifier of the menu button.
    var identifier: String?

    /// The name of an option.
    let optionTitle: (Option) -> String

    /// The accessibility identifier of an option, `nil` for none.
    let optionIdentifier: (Option) -> String?

    /// Extra actions below the options.
    let actions: Actions

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: Initialization

    /// Creates a choice row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - options: The options.
    ///   - selection: The current option.
    ///   - identifier: The accessibility identifier of the menu button.
    ///   - optionTitle: The name of an option.
    ///   - optionIdentifier: The accessibility identifier of an option.
    ///   - actions: Extra actions below the options.
    ///
    init(
        _ title: String,
        options: [Option],
        selection: Binding<Option>,
        identifier: String? = nil,
        optionTitle: @escaping (Option) -> String,
        optionIdentifier: @escaping (Option) -> String? = { _ in nil },
        @ViewBuilder actions: () -> Actions,
    ) {
        self.title = title
        self.options = options
        _selection = selection
        self.identifier = identifier
        self.optionTitle = optionTitle
        self.optionIdentifier = optionIdentifier
        self.actions = actions()
    }

    // MARK: View

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(optionTitle(option))
                        .accessibilityIdentifier(optionIdentifier(option) ?? optionTitle(option))
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            actions
        } label: {
            label
        }
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityLabel(title)
        .accessibilityValue(optionTitle(selection))
    }

    /// The row: title, choice, chevrons.
    @ViewBuilder private var label: some View {
        let choice = HStack(spacing: PassYDesign.Spacing.xSmall) {
            Text(optionTitle(selection))
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .imageScale(.small)
        }
        .foregroundStyle(.tint)

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    Text(title).foregroundStyle(Color.primary)
                    choice
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: PassYDesign.Spacing.medium) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                        .layoutPriority(1)
                    Spacer(minLength: PassYDesign.Spacing.small)
                    choice
                }
            }
        }
        .font(.body)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

extension PassYPickerRow where Option: Menuable {
    /// Creates a choice row of `Menuable` options (their localized names and identifiers).
    init(
        _ title: String,
        options: [Option],
        selection: Binding<Option>,
        identifier: String? = nil,
        @ViewBuilder actions: () -> Actions,
    ) {
        self.init(
            title,
            options: options,
            selection: selection,
            identifier: identifier,
            optionTitle: \.localizedName,
            optionIdentifier: \.accessibilityId,
            actions: actions,
        )
    }
}

extension PassYPickerRow where Option: Menuable, Actions == EmptyView {
    /// Creates a choice row of `Menuable` options without extra actions.
    init(_ title: String, options: [Option], selection: Binding<Option>, identifier: String? = nil) {
        self.init(title, options: options, selection: selection, identifier: identifier) { EmptyView() }
    }
}

extension PassYPickerRow where Actions == EmptyView {
    /// Creates a choice row of any options without extra actions.
    init(
        _ title: String,
        options: [Option],
        selection: Binding<Option>,
        identifier: String? = nil,
        optionTitle: @escaping (Option) -> String,
    ) {
        self.init(title, options: options, selection: selection, identifier: identifier, optionTitle: optionTitle) {
            EmptyView()
        }
    }
}

// MARK: - Previews

#if DEBUG
private enum PreviewFruit: String, CaseIterable, Menuable {
    case apple, banana
    var localizedName: String { rawValue.capitalized }
}

#Preview("Picker rows") {
    @Previewable @SwiftUI.State var fruit = PreviewFruit.apple
    Form {
        Section {
            PassYPickerRow("Fruit", options: PreviewFruit.allCases, selection: $fruit)
            PassYPickerRow("Folder", options: PreviewFruit.allCases, selection: $fruit) {
                Button("Add folder", systemImage: "folder.badge.plus") {}
            }
        }
    }
}
#endif
