import BitwardenResources
import SwiftUI

// MARK: - PasswordStrengthIndicator

/// A horizontal bar that changes color to indicate the strength of an entered password.
///
struct PasswordStrengthIndicator: View {
    // MARK: Properties

    /// The password's strength.
    let passwordStrength: PasswordStrength

    /// The current count of characters in the password.
    let passwordTextCount: Int

    /// The required text count for the password
    let requiredTextCount: Int

    // MARK: Computed Properties

    /// Whether the entered password has met the minimum length required.
    var hasPasswordMinimumLength: Bool {
        passwordTextCount >= requiredTextCount
    }

    // MARK: View

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: hasPasswordMinimumLength ? passwordStrength.strengthPercent : 0)
                .progressViewStyle(.linear)
                .tint(passwordStrength.color)
                .animation(.easeIn, value: hasPasswordMinimumLength ? passwordStrength.strengthPercent : 0)
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(Localizations.xCharacters(requiredTextCount))
                } icon: {
                    Image(systemName: hasPasswordMinimumLength ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(hasPasswordMinimumLength ? Color.green : Color.secondary)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

                Spacer()

                if hasPasswordMinimumLength {
                    Text(passwordStrength.text ?? "")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(passwordStrength.color)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
    }

    /// Initialize a `PasswordStrengthIndicator`.
    ///
    /// - Parameters:
    ///   - passwordStrengthScore: The scoring metric representing the strength of the
    ///     entered password. The value's range is 0-4. Defaults to `nil`.
    ///   - passwordTextCount: The current length of the entered password.
    ///   - requiredTextCount: The required minimum length for the password.
    ///
    init(
        passwordStrengthScore: UInt8? = nil,
        passwordTextCount: Int = 0,
        requiredTextCount: Int = 0,
    ) {
        passwordStrength = PasswordStrength(score: passwordStrengthScore)
        self.passwordTextCount = passwordTextCount
        self.requiredTextCount = requiredTextCount
    }
}

// MARK: - PasswordStrength

extension PasswordStrengthIndicator {
    /// A helper object that determines the view properties for the password strength indicator
    /// based on the password strength score.
    ///
    struct PasswordStrength {
        // MARK: Properties

        /// The color of the strength text and the indicator bar (system colours).
        let color: Color

        /// The strength text to display beneath the indicator bar.
        let text: String?

        /// The percent that the indicator bar should be filled.
        let strengthPercent: CGFloat

        // MARK: Initialization

        /// Initialize `PasswordStrength` with the password score.
        ///
        /// - Parameter score: The password score indicating the strength of the password. The
        ///     value's range is 0-4.
        ///
        init(score: UInt8?) {
            switch score {
            case 0, 1:
                color = .red
                text = Localizations.weak
            case 2:
                color = .orange
                text = Localizations.weak
            case 3:
                color = .blue
                text = Localizations.good
            case 4:
                color = .green
                text = Localizations.strong
            default:
                // Provide the initial color when not visible so the color isn't animated when the
                // first segment appears.
                color = .red
                text = nil
            }

            if let score, score <= 4 {
                strengthPercent = CGFloat(score + 1) / 5
            } else {
                strengthPercent = 0
            }
        }
    }
}

// MARK: Previews

#if DEBUG
#Preview {
    ScrollView {
        VStack {
            PasswordStrengthIndicator(
                passwordStrengthScore: nil,
                passwordTextCount: 0,
            )

            ForEach(UInt8(0) ... UInt8(4), id: \.self) { score in
                PasswordStrengthIndicator(
                    passwordStrengthScore: score,
                    passwordTextCount: 0,
                )
            }

            PasswordStrengthIndicator(
                passwordStrengthScore: UInt8(4),
                passwordTextCount: 0,
            )

            PasswordStrengthIndicator(
                passwordStrengthScore: UInt8(12),
                passwordTextCount: 5,
                requiredTextCount: 12,
            )
        }
        .padding()
    }
}
#endif
