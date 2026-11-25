import SwiftUI

// MARK: - PassYSectionHeader

/// The header of a card section: the title in sentence case (no upper-casing), an optional count and, for collapsible
/// sections, a chevron. A collapsible header is one button that toggles the section; its label reads the title and
/// the number of items.
///
/// ```swift
/// Section { rows } header: { PassYSectionHeader("Folders", count: 4) }
/// Section { rows } header: {
///     PassYSectionHeader("Favorites", count: 3, isExpanded: expanded, identifier: "SectionExpandButton_fav") { toggle() }
/// }
/// ```
///
struct PassYSectionHeader: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The number shown at the trailing edge, `nil` for none.
    var count: Int?

    /// For collapsible sections: whether the section is expanded (`nil`: not collapsible).
    var isExpanded: Bool?

    /// The spoken label of the count ("3 items"), `nil` for the plain number.
    var countLabel: String?

    /// The accessibility identifier of the toggle button.
    var identifier: String?

    /// Toggles the section (collapsible sections only).
    var toggle: (() -> Void)?

    // MARK: Initialization

    /// Creates a section header.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - count: The number shown at the trailing edge.
    ///   - countLabel: The spoken label of the count.
    ///   - isExpanded: For collapsible sections: whether the section is expanded.
    ///   - identifier: The accessibility identifier of the toggle button.
    ///   - toggle: Toggles the section.
    ///
    init(
        _ title: String,
        count: Int? = nil,
        countLabel: String? = nil,
        isExpanded: Bool? = nil,
        identifier: String? = nil,
        toggle: (() -> Void)? = nil,
    ) {
        self.title = title
        self.count = count
        self.countLabel = countLabel
        self.isExpanded = isExpanded
        self.identifier = identifier
        self.toggle = toggle
    }

    // MARK: View

    var body: some View {
        if let toggle, let isExpanded {
            Button(action: toggle) {
                content(isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier ?? "")
            .accessibilityLabel(spokenLabel)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
        } else {
            content(isExpanded: nil)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// What VoiceOver reads: the title and the count.
    private var spokenLabel: String {
        guard let count else { return title }
        return "\(title), \(countLabel ?? "\(count)")"
    }

    /// The visible header.
    private func content(isExpanded: Bool?) -> some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            Text(title)
            Spacer(minLength: PassYDesign.Spacing.small)
            if let count {
                Text("\(count)")
                    .monospacedDigit()
            }
            if let isExpanded {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.snappy, value: isExpanded)
            }
        }
        .textCase(nil)
        .passYFont(.sectionHeader)
        // The secondary label colour is too light on the grouped background (contrast audit).
        .foregroundStyle(Color(.label).opacity(0.75))
        .contentShape(Rectangle())
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Section headers") {
    List {
        Section {
            Text("Row")
        } header: {
            PassYSectionHeader("Folders", count: 4)
        }
        Section {
            Text("Row")
        } header: {
            PassYSectionHeader("Favorites", count: 3, isExpanded: true) {}
        }
        Section {} header: {
            PassYSectionHeader("No folder", count: 12, isExpanded: false) {}
        }
    }
    .passYCardList(reservesBottomBarSpace: false)
}
#endif
