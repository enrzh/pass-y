import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: BitwardenSegmentedControl

/// A segmented control: the native segmented picker on Liquid Glass.
///
struct BitwardenSegmentedControl<T: Menuable & Identifiable>: View {
    // MARK: Properties

    /// A closure that returns whether a selection should be disabled from user input.
    let isSelectionDisabled: (T) -> Bool

    /// The currently selected segment.
    @Binding var selection: T

    /// The list of selections to show in the control.
    let selections: [T]

    // MARK: View

    var body: some View {
        Picker(
            selection: $selection,
        ) {
            ForEach(selections) { type in
                Text(type.localizedName)
                    .tag(type)
                    .selectionDisabled(isSelectionDisabled(type))
                    .accessibilityIdentifier(type.accessibilityId)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .glassEffect()
    }

    // MARK: Initialization

    /// Initialize a `BitwardenSegmentedControl`.
    ///
    /// - Parameters:
    ///   - isSelectionDisabled: A closure that returns whether a selection should be disabled from user input.
    ///   - selection: A binding to the currently selected segment.
    ///   - selections: The list of selections to show in the control.
    ///
    init(
        isSelectionDisabled: @escaping (T) -> Bool = { _ in false },
        selection: Binding<T>,
        selections: [T],
    ) {
        self.isSelectionDisabled = isSelectionDisabled
        _selection = selection
        self.selections = selections
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    @Previewable @SwiftUI.State var selection = GeneratorType.password

    BitwardenSegmentedControl(
        selection: $selection,
        selections: GeneratorType.allCases,
    )
    .padding()
}
#endif
