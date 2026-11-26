import SwiftUI

// MARK: - PassYFingerprintPhrase

/// The fingerprint phrase of a device or login request as a `Form` row: the caption above, the phrase in a monospaced
/// font in system pink (the colour users compare between devices), selectable for copying and wrapped at any text size.
///
/// ```swift
/// Section { PassYFingerprintPhrase(title: Localizations.fingerprintPhrase, phrase: request.fingerprintPhrase) }
/// ```
///
struct PassYFingerprintPhrase: View {
    // MARK: Properties

    /// The caption above the phrase.
    let title: String

    /// The phrase (words joined by hyphens).
    let phrase: String

    /// The accessibility identifier of the caption.
    var titleIdentifier: String? = "FingerprintValueLabel"

    /// The accessibility identifier of the phrase.
    var phraseIdentifier: String? = "FingerprintPhraseValue"

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: PassYDesign.Spacing.xSmall) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(titleIdentifier ?? "")
            Text(phrase)
                .font(.body.monospaced())
                .foregroundStyle(.pink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityIdentifier(phraseIdentifier ?? "")
        }
        .padding(.vertical, PassYDesign.Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Fingerprint phrase") {
    Form {
        Section {
            PassYFingerprintPhrase(title: "Fingerprint phrase", phrase: "which-ninja-turtle-is-the-best")
        }
    }
}
#endif
