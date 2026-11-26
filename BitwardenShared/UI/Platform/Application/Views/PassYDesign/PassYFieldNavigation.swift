import SwiftUI

// MARK: - PassYFieldOrder

/// The order of the text fields of a form, for the previous/next keyboard navigation (`passYFieldNavigation`).
struct PassYFieldOrder<Field: Hashable> {
    /// The fields in reading order (only the ones currently on screen).
    let fields: [Field]

    /// The field before `field`, `nil` at the first.
    func previous(_ field: Field?) -> Field? {
        guard let field, let index = fields.firstIndex(of: field), index > 0 else { return nil }
        return fields[index - 1]
    }

    /// The field after `field`, `nil` at the last.
    func next(_ field: Field?) -> Field? {
        guard let field, let index = fields.firstIndex(of: field), index + 1 < fields.count else { return nil }
        return fields[index + 1]
    }
}

// MARK: - View + field navigation

extension View {
    /// Adds keyboard navigation to a form: the Return key moves to the next field (`.next`, the last field shows
    /// `.done` and ends editing) and the keyboard bar has previous/next chevrons. Apply it once to the `Form`, not to
    /// the rows (one keyboard toolbar per page). The form scrolls the focused field into view by itself.
    ///
    /// - Parameters:
    ///   - focus: The focus state of the form.
    ///   - order: The fields in reading order.
    ///
    func passYFieldNavigation<Field: Hashable>(
        _ focus: FocusState<Field?>.Binding,
        order: [Field],
    ) -> some View {
        modifier(PassYFieldNavigationModifier(focus: focus, order: PassYFieldOrder(fields: order)))
    }
}

/// The keyboard navigation of `passYFieldNavigation`.
private struct PassYFieldNavigationModifier<Field: Hashable>: ViewModifier {
    let focus: FocusState<Field?>.Binding
    let order: PassYFieldOrder<Field>

    func body(content: Content) -> some View {
        content
            .submitLabel(order.next(focus.wrappedValue) == nil ? .done : .next)
            .onSubmit {
                focus.wrappedValue = order.next(focus.wrappedValue)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Previous", systemImage: "chevron.up") {
                        focus.wrappedValue = order.previous(focus.wrappedValue)
                    }
                    .disabled(order.previous(focus.wrappedValue) == nil)
                    .accessibilityIdentifier("KeyboardPreviousFieldButton")

                    Button("Next", systemImage: "chevron.down") {
                        focus.wrappedValue = order.next(focus.wrappedValue)
                    }
                    .disabled(order.next(focus.wrappedValue) == nil)
                    .accessibilityIdentifier("KeyboardNextFieldButton")

                    Spacer()
                }
            }
    }
}

// MARK: - Previews

#if DEBUG
private enum PreviewField: Hashable { case first, last }

#Preview("Field navigation") {
    @Previewable @SwiftUI.State var first = ""
    @Previewable @SwiftUI.State var last = ""
    @Previewable @FocusState var focus: PreviewField?
    Form {
        PassYFormField("First name", text: $first, focus: .field($focus, equals: .first))
        PassYFormField("Last name", text: $last, focus: .field($focus, equals: .last))
    }
    .passYFieldNavigation($focus, order: [.first, .last])
}
#endif
