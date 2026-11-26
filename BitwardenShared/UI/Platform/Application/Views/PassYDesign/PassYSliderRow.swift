import SwiftUI

// MARK: - PassYSliderRow

/// A range row of a Pass-Y form (generator length): the title and the current value on one line, the system `Slider`
/// below it, with a `Stepper`-like fine adjustment through VoiceOver's increment and decrement.
///
/// ```swift
/// PassYSliderRow(Localizations.length, value: $length, in: 5 ... 128, identifier: "PasswordLengthSlider")
/// ```
///
struct PassYSliderRow: View {
    /// The title.
    let title: String

    /// The value.
    @Binding var value: Double

    /// The allowed values.
    let range: ClosedRange<Double>

    /// The step.
    var step: Double = 1

    /// The accessibility identifier of the slider.
    var identifier: String?

    /// The accessibility identifier of the value text.
    var valueIdentifier: String?

    /// Called when a drag ends (e.g. to regenerate once instead of on every step).
    var onEditingChanged: ((Bool) -> Void)?

    /// Creates a range row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - value: The value.
    ///   - range: The allowed values.
    ///   - step: The step.
    ///   - identifier: The accessibility identifier of the slider.
    ///   - valueIdentifier: The accessibility identifier of the value text.
    ///   - onEditingChanged: Called when a drag starts and ends.
    ///
    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        identifier: String? = nil,
        valueIdentifier: String? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil,
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.identifier = identifier
        self.valueIdentifier = valueIdentifier
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
            HStack {
                Text(title)
                Spacer(minLength: PassYDesign.Spacing.small)
                Text("\(Int(value))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityIdentifier(valueIdentifier ?? "\(title)Value")
            }
            .font(.body)
            .accessibilityElement(children: .combine)

            Slider(value: $value, in: range, step: step) {
                Text(title)
            } onEditingChanged: { editing in
                onEditingChanged?(editing)
            }
            .accessibilityIdentifier(identifier ?? title)
            .accessibilityValue("\(Int(value))")
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Slider row") {
    @Previewable @SwiftUI.State var length = 14.0
    Form {
        Section { PassYSliderRow("Length", value: $length, in: 5 ... 128) }
    }
}
#endif
