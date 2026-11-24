import BitwardenResources
import SwiftUI

// MARK: - Toast

/// A data model for a toast.
///
public struct Toast: Equatable, Identifiable, Sendable {
    // MARK: Types

    /// A mode that captures what sort of toast this is.
    public enum ToastMode: Sendable {
        /// The toast should dismiss itself after a few seconds.
        case automaticDismiss

        /// The toast should not automatically dismiss itself, and something else should do the dismissal.
        case manualDismiss
    }

    // MARK: Properties

    /// A unique identifier of the toast.
    public let id = UUID()

    /// The mode of the toast.
    let mode: ToastMode

    /// The title text displayed in the toast.
    public let title: String

    /// The subtitle text displayed in the toast.
    let subtitle: String?

    // MARK: Initialization

    /// Initialize a `Toast`.
    ///
    /// - Parameters:
    ///   - title: The title text displayed in the toast.
    ///   - subtitle: The subtitle text displayed in the toast.
    ///   - mode: The mode for the toast
    ///
    public init(title: String, subtitle: String? = nil, mode: ToastMode = .automaticDismiss) {
        self.title = title
        self.subtitle = subtitle
        self.mode = mode
    }

    public static func == (lhs: Toast, rhs: Toast) -> Bool {
        // Exclude `id` from `Equatable`, it's only used by the view to handle animations between toasts.
        lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
    }
}

// MARK: - Toast + Presentation

extension Toast {
    /// The kind of SF Symbol shown in front of the toast text.
    enum Symbol: Equatable {
        /// A generic confirmation.
        case success
        /// Something was copied to the clipboard.
        case copied
        /// Something went wrong.
        case failure

        /// The SF Symbol name.
        var name: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .copied: "doc.on.doc"
            case .failure: "exclamationmark.triangle.fill"
            }
        }

        /// The tint of the symbol.
        var tint: Color {
            switch self {
            case .success: .green
            case .copied: .secondary
            case .failure: .orange
            }
        }
    }

    /// The symbol to show, chosen from the text where there is a natural mapping (defaults to a checkmark).
    var symbol: Symbol {
        let text = [title, subtitle].compactMap(\.self).joined(separator: " ").lowercased()
        let failureWords = [
            "error", "fail", "invalid", "unable", "couldn't", "could not", "cannot", "can't",
            "fehler", "fehlgeschlagen", "ungültig",
        ]
        if failureWords.contains(where: text.contains) { return .failure }
        let copyWords = ["copied", "kopiert", "copiado", "copié"]
        if copyWords.contains(where: text.contains) { return .copied }
        return .success
    }
}

// MARK: - ToastView

/// A view that displays a toast message which is shown when the binding has a value and is hidden
/// after a delay. It is presented as a calm, system style glass capsule with a leading SF Symbol.
///
public struct ToastView: View {
    // MARK: Properties

    /// A binding to the toast to show.
    @Binding var toast: Toast?

    /// Whether the user prefers reduced motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A counter incremented whenever a toast appears, used to trigger haptic feedback.
    @State private var feedbackTrigger = 0

    public var body: some View {
        if let toast {
            let symbol = toast.symbol
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(symbol.tint)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(toast.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let subtitle = toast.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            .id(toast.id)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("ToastElement")
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 16)
            .sensoryFeedback(trigger: feedbackTrigger) { _, _ in
                symbol == .failure ? .warning : .success
            }
            .task(id: toast.id) {
                feedbackTrigger += 1

                // The toast isn't part of the focused view hierarchy and may dismiss before
                // VoiceOver can reach it, so announce its contents.
                postAccessibilityAnnouncement(for: toast)

                guard self.toast?.mode == .automaticDismiss else { return }
                do {
                    try await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .snappy) {
                        self.toast = nil
                    }
                } catch {
                    // No-op: Skip the animation if the task/sleep is cancelled.
                }
            }
            .onDisappear {
                self.toast = nil
            }
        }
    }

    /// Initializes a `ToastView`.
    ///
    /// - Parameters:
    ///   - toast: A binding to the toast to show.
    public init(toast: Binding<Toast?>) {
        _toast = toast
    }

    // MARK: Private Methods

    /// Posts a VoiceOver announcement with the contents of the toast.
    ///
    /// - Parameter toast: The toast to announce.
    ///
    private func postAccessibilityAnnouncement(for toast: Toast) {
        let message = [toast.title, toast.subtitle]
            .compactMap(\.self)
            .joined(separator: ", ")

        // Use a high priority so the announcement isn't dropped when shown alongside a
        // screen transition, such as dismissing the share sheet.
        let announcement = NSAttributedString(
            string: message,
            attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high],
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - View

public extension View {
    /// Adds a toast view in an overlay at the bottom of the view.
    ///
    /// - Parameters:
    ///     - toast: A binding to the toast to show.
    ///     - additionalBottomPadding: Additional bottom padding to apply to the toast.
    /// - Returns: A view that displays a toast.
    ///
    func toast(_ toast: Binding<Toast?>, additionalBottomPadding: CGFloat = 0) -> some View {
        overlay(alignment: .bottom) {
            ToastView(toast: toast)
                .padding(.bottom, 12 + additionalBottomPadding)
                .animation(.snappy, value: toast.wrappedValue)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Toasts") {
    VStack(spacing: 16) {
        ToastView(toast: .constant(Toast(title: "Copied")))

        ToastView(toast: .constant(Toast(title: "Password copied")))

        ToastView(toast: .constant(Toast(title: "Saved", subtitle: "Lorem ipsum dolor sit amet.")))

        ToastView(toast: .constant(Toast(title: "Something went wrong")))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Toast Overlay") {
    NavigationStack {
        List(0 ..< 20, id: \.self) { Text("Row \($0)") }
            .toast(.constant(Toast(title: "Copied")))
    }
}
#endif
