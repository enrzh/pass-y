import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - SendItemAccessCountStepper

/// A view containing the stepper component for a send's maximum access count.
///
struct SendItemAccessCountStepper: View {
    // MARK: Properties

    /// The number of times the send has been accessed.
    let currentAccessCount: Int?

    /// Whether the maximum access count info text should be displayed in the footer.
    let displayInfoText: Bool

    /// A binding for changing the maximum access account for the send in the stepper.
    @Binding var maximumAccessCount: Int

    // MARK: View

    var body: some View {
        Section {
            PassYStepperRow(
                Localizations.maximumAccessCount,
                value: $maximumAccessCount,
                in: 0 ... Int.max,
                identifier: "SendMaxAccessCountEntry",
                textFieldIdentifier: "MaxAccessCountTextField",
            )
        } footer: {
            VStack(alignment: .leading, spacing: PassYDesign.Spacing.xxSmall) {
                if displayInfoText {
                    Text(Localizations.maximumAccessCountInfo)
                }

                if let currentAccessCount, maximumAccessCount > 0 {
                    Text("\(Localizations.currentAccessCount): \(Text("\(currentAccessCount)").fontWeight(.semibold))")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Initialization

    /// Initialize a `SendItemAccessCountStepper`.
    ///
    /// - Parameters:
    ///   - currentAccessCount: The number of times the send has been accessed.
    ///   - displayInfoText: Whether the maximum access count info text should be displayed in the footer.
    ///   - maximumAccessCount: A binding for changing the maximum access account for the send in the stepper.
    ///
    init(currentAccessCount: Int?, displayInfoText: Bool = true, maximumAccessCount: Binding<Int>) {
        self.currentAccessCount = currentAccessCount
        self.displayInfoText = displayInfoText
        _maximumAccessCount = maximumAccessCount
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    @Previewable @SwiftUI.State var maximumAccessCount = 5

    Form {
        SendItemAccessCountStepper(currentAccessCount: 0, maximumAccessCount: $maximumAccessCount)
    }
}
#endif
