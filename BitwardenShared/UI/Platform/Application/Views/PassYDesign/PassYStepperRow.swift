import SwiftUI

// MARK: - PassYStepperRow

/// A number row of a Pass-Y form: the title, the current value (monospaced digits, or a word such as "None" for an
/// unset value) and the system `Stepper`. Used for counts (Send access count, generator minimums).
///
/// ```swift
/// PassYStepperRow(Localizations.maximumAccessCount, value: $count, in: 0 ... 1_000_000, identifier: "SendMaxAccessCountEntry")
/// ```
///
struct PassYStepperRow: View {
    /// The title.
    let title: String

    /// The value.
    @Binding var value: Int

    /// The allowed values.
    let range: ClosedRange<Int>

    /// The text shown for the lowest value instead of its number (e.g. "None"), `nil` for the number.
    var lowestValueText: String?

    /// The accessibility identifier of the stepper.
    var identifier: String?

    /// The accessibility identifier of the number field; `nil` shows the value as text (no typing).
    var textFieldIdentifier: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Creates a number row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - value: The value.
    ///   - range: The allowed values.
    ///   - lowestValueText: The text shown for the lowest value.
    ///   - identifier: The accessibility identifier of the stepper.
    ///   - textFieldIdentifier: The accessibility identifier of a number field for typing large values; `nil`
    ///     shows the value as text.
    ///
    init(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        lowestValueText: String? = nil,
        identifier: String? = nil,
        textFieldIdentifier: String? = nil,
    ) {
        self.title = title
        _value = value
        self.range = range
        self.lowestValueText = lowestValueText
        self.identifier = identifier
        self.textFieldIdentifier = textFieldIdentifier
    }

    /// The displayed value.
    var valueText: String {
        if value == range.lowerBound, let lowestValueText { return lowestValueText }
        return "\(value)"
    }

    /// The value as typed text: the lowest value shows as an empty field, non-digits are ignored, the value is
    /// clamped to the range.
    private var typedValue: Binding<String> {
        Binding(
            get: { value == range.lowerBound ? "" : "\(value)" },
            set: { text in
                let digits = text.filter(\.isNumber)
                let number = Int(digits.prefix(12)) ?? range.lowerBound
                value = min(max(number, range.lowerBound), range.upperBound)
            },
        )
    }

    var body: some View {
        Stepper(value: $value, in: range) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
                    Text(title)
                    Text(valueText).foregroundStyle(.secondary).monospacedDigit()
                }
            } else {
                HStack {
                    Text(title)
                    Spacer(minLength: PassYDesign.Spacing.small)
                    if let textFieldIdentifier {
                        TextField(title, text: typedValue, prompt: Text(lowestValueText ?? "\(range.lowerBound)"))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(minWidth: 44, maxWidth: 120)
                            .accessibilityIdentifier(textFieldIdentifier)
                    } else {
                        Text(valueText)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .font(.body)
        .frame(minHeight: 44)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityValue(valueText)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Stepper row") {
    @Previewable @SwiftUI.State var count = 0
    Form {
        Section { PassYStepperRow("Maximum access count", value: $count, in: 0 ... 100, lowestValueText: "None") }
    }
}
#endif
