import SwiftUI

// MARK: - PassYDisclosureSection

/// Rarely used options of a form behind one row ("Additional options"): a row with the title and a chevron that turns
/// when it opens; the options follow as their own sections. Keeps every field reachable while the form stays short.
///
/// ```swift
/// PassYDisclosureSection(Localizations.additionalOptions, isExpanded: $expanded) {
///     Section { notesField }
///     Section { repromptToggle }
/// }
/// ```
///
struct PassYDisclosureSection<Content: View>: View {
    /// The title of the row.
    let title: String

    /// Whether the options are shown.
    @Binding var isExpanded: Bool

    /// The accessibility identifier of the row.
    var identifier: String

    /// The options (sections).
    @ViewBuilder let content: () -> Content

    /// Creates a disclosure section.
    ///
    /// - Parameters:
    ///   - title: The title of the row.
    ///   - isExpanded: Whether the options are shown.
    ///   - identifier: The accessibility identifier of the row.
    ///   - content: The options.
    ///
    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        identifier: String = "ExpandSectionButton",
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.title = title
        _isExpanded = isExpanded
        self.identifier = identifier
        self.content = content
    }

    var body: some View {
        Section {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: PassYDesign.Spacing.small) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer(minLength: PassYDesign.Spacing.small)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .font(.body)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(identifier)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
        }

        if isExpanded {
            content()
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Disclosure section") {
    @Previewable @SwiftUI.State var expanded = true
    Form {
        Section { Text("Name") }
        PassYDisclosureSection("Additional options", isExpanded: $expanded) {
            Section { Text("Notes") }
            Section { Toggle("Re-prompt", isOn: .constant(false)) }
        }
    }
}
#endif
