import BitwardenResources
import SwiftUI

// MARK: - ToastBannerView

/// A toast banner view which displays a toast message and doesn't automatically dismiss. This is
/// similar to `ToastView` but has a close button to dismiss the banner and supports displaying
/// custom buttons at the bottom of the banner.
///
struct ToastBannerView<ButtonContent: View>: View {
    // MARK: Properties

    /// A button content view to display below the title and subtitle of the toast banner.
    let buttonContent: ButtonContent

    /// A binding which controls if the toast banner is visible.
    @Binding var isVisible: Bool

    /// The subtitle text displayed in the toast banner.
    let subtitle: String

    /// The title text displayed in the toast banner.
    let title: String

    // MARK: View

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "record.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isVisible = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Localizations.close)
                    .padding(-12) // Keeps the 44 pt tap area without growing the banner.
                }

                buttonContent
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.footnote.weight(.semibold))
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("ToastElement")
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 16)
        }
    }

    // MARK: Initialization

    /// Initialize a `ToastBannerView`.
    ///
    /// - Parameters:
    ///   - title: The title text displayed in the toast banner.
    ///   - subtitle: The subtitle text displayed in the toast banner.
    ///   - isVisible: A binding which controls if the toast banner is visible.
    ///   - buttonContent: A button content view to display below the title and subtitle of the toast banner.
    ///
    init(
        title: String,
        subtitle: String,
        isVisible: Binding<Bool>,
        @ViewBuilder buttonContent: () -> ButtonContent,
    ) {
        self.title = title
        self.subtitle = subtitle
        _isVisible = isVisible
        self.buttonContent = buttonContent()
    }
}

// MARK: - View

public extension View {
    /// Displays a toast banner view in an overlay at the bottom of the view.
    ///
    /// - Parameters:
    ///   - title: The title text displayed in the toast banner.
    ///   - subtitle: The subtitle text displayed in the toast banner.
    ///   - additionalBottomPadding: Additional bottom padding to apply to the toast banner.
    ///   - isVisible: A binding which controls if the toast banner is visible.
    ///   - buttonContent: A button content view to display below the title and subtitle of the toast banner.
    /// - Returns: A view that displays a toast banner.
    ///
    func toastBanner<ButtonContent: View>(
        title: String,
        subtitle: String,
        additionalBottomPadding: CGFloat = 0,
        isVisible: Binding<Bool>,
        @ViewBuilder buttonContent: () -> ButtonContent,
    ) -> some View {
        overlay(alignment: .bottom) {
            ToastBannerView(
                title: title,
                subtitle: subtitle,
                isVisible: isVisible,
                buttonContent: buttonContent,
            )
            .padding(.bottom, 12 + additionalBottomPadding)
            .animation(.easeInOut, value: isVisible.wrappedValue)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ToastBannerView(
        title: "Title",
        subtitle: "Subtitle",
        isVisible: .constant(true),
    ) {
        Button("Tap me") {}
    }
    .padding()
}
#endif
