import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - PassYDateRow

/// An optional calendar date of a Pass-Y form (date of birth, issue and expiry dates): unset, the row shows the title
/// and an "Add" button; set, the system compact `DatePicker` and a clear button. Values are stored as UTC calendar days
/// (like the vault) and shown as the same day in the local time zone.
///
/// ```swift
/// PassYDateRow(Localizations.dateOfBirth, date: $birthday, in: .distantPast ... .now, identifier: "BirthEntry")
/// ```
///
struct PassYDateRow: View {
    // MARK: Properties

    /// The title.
    let title: String

    /// The date (a UTC calendar day), `nil` while unset.
    @Binding var date: Date?

    /// The allowed days (UTC calendar days), `nil` for any.
    var range: ClosedRange<Date>?

    /// The day set by "Add" (a UTC calendar day).
    var defaultDate: Date

    /// The accessibility identifier of the picker; the buttons append `AddButton` and `ClearButton`.
    var identifier: String?

    // MARK: Initialization

    /// Creates a date row.
    ///
    /// - Parameters:
    ///   - title: The title.
    ///   - date: The date (a UTC calendar day), `nil` while unset.
    ///   - range: The allowed days.
    ///   - defaultDate: The day set by "Add".
    ///   - identifier: The accessibility identifier.
    ///
    init(
        _ title: String,
        date: Binding<Date?>,
        in range: ClosedRange<Date>? = nil,
        defaultDate: Date = Date().asUTCCalendarDay(),
        identifier: String? = nil,
    ) {
        self.title = title
        _date = date
        self.range = range
        self.defaultDate = range.map { min(max(defaultDate, $0.lowerBound), $0.upperBound) } ?? defaultDate
        self.identifier = identifier
    }

    // MARK: View

    var body: some View {
        HStack(spacing: PassYDesign.Spacing.small) {
            if date != nil {
                picker
                    .accessibilityIdentifier(identifier ?? title)

                Button {
                    withAnimation(.snappy) { date = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Localizations.clearFieldName(title))
                .accessibilityIdentifier("\(identifier ?? title)ClearButton")
            } else {
                Text(title)
                Spacer(minLength: PassYDesign.Spacing.small)
                Button(Localizations.add) {
                    withAnimation(.snappy) { date = defaultDate }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(Localizations.add), \(title)")
                .accessibilityIdentifier("\(identifier ?? title)AddButton")
            }
        }
        .font(.body)
        .frame(minHeight: 44)
    }

    /// The compact system picker on the local calendar day.
    @ViewBuilder private var picker: some View {
        if let range {
            DatePicker(
                title,
                selection: localDay,
                in: range.lowerBound.asLocalCalendarDay() ... range.upperBound.asLocalCalendarDay(),
                displayedComponents: .date,
            )
        } else {
            DatePicker(title, selection: localDay, displayedComponents: .date)
        }
    }

    /// The selected day in the local time zone, written back as a UTC calendar day.
    private var localDay: Binding<Date> {
        Binding(
            get: { (date ?? defaultDate).asLocalCalendarDay() },
            set: { date = $0.asUTCCalendarDay() },
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Date rows") {
    @Previewable @SwiftUI.State var unset: Date?
    @Previewable @SwiftUI.State var set: Date? = Date()
    Form {
        PassYDateRow("Date of birth", date: $unset, in: .distantPast ... Date())
        PassYDateRow("Expiration date", date: $set)
    }
}
#endif
