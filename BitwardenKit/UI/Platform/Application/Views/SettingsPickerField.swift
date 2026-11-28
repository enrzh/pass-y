import BitwardenResources
import SwiftUI

// MARK: - SettingsPickerField

/// A field that displays a `CountdownDatePicker` when interacted with.
///
public struct SettingsPickerField: View {
    // MARK: Properties

    /// The accessibility label used for the custom timeout value.
    let customTimeoutAccessibilityLabel: String

    /// The custom session timeout value.
    let customTimeoutValue: String

    /// The footer text displayed below the toggle.
    let footer: String?

    /// The date picker value.
    @Binding var pickerValue: Int

    /// Whether or not to show the date picker.
    @SwiftUI.State var showTimePicker = false

    /// The title of the menu field.
    let title: String

    // MARK: View

    public var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    showTimePicker.toggle()
                }
            } label: {
                HStack {
                    if !title.isEmpty {
                        Text(title)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }

                    // The value chip of a compact system date picker.
                    Text(customTimeoutValue)
                        .monospacedDigit()
                        .accessibilityLabel(customTimeoutAccessibilityLabel)
                        .multilineTextAlignment(title.isEmpty ? .leading : .trailing)
                        .foregroundStyle(showTimePicker ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: .capsule)

                    if title.isEmpty {
                        Spacer()
                    }
                }
                .font(.body)
                .id(title)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if footer != nil {
                Divider()
                    .padding(.top, 8)
            }

            if showTimePicker {
                CountdownDatePicker(duration: $pickerValue)
                    .frame(maxWidth: .infinity)

                if footer != nil {
                    Divider()
                }
            }

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Initialization

    /// Initializes a new `SettingsPickerField`.
    ///
    /// - Parameters:
    ///   - title: The title of the field.
    ///   - footer: The footer text displayed below the menu field.
    ///   - customTimeoutValue: The custom session timeout value.
    ///   - pickerValue: The date picker value.
    ///   - customTimeoutAccessibilityLabel: The accessibility label used for the custom timeout value.
    ///
    public init(
        title: String,
        footer: String? = nil,
        customTimeoutValue: String,
        pickerValue: Binding<Int>,
        customTimeoutAccessibilityLabel: String,
    ) {
        self.customTimeoutAccessibilityLabel = customTimeoutAccessibilityLabel
        self.customTimeoutValue = customTimeoutValue
        self.footer = footer
        _pickerValue = pickerValue
        self.title = title
    }
}

// MARK: Previews

#Preview {
    SettingsPickerField(
        title: "Custom",
        footer: nil,
        customTimeoutValue: "1:00",
        pickerValue: .constant(1),
        customTimeoutAccessibilityLabel: "one hour, zero minutes",
    )

    SettingsPickerField(
        title: "",
        footer: nil,
        customTimeoutValue: "1:00",
        pickerValue: .constant(1),
        customTimeoutAccessibilityLabel: "one hour, zero minutes",
    )
}
