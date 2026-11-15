import BitwardenResources
import SwiftUI

// MARK: - NativeForm environment

private struct IsNativeFormKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the shared field components are rendered as rows of a native `Form`/`List`
    /// (no own card, background or rounded corners; sections become real `Section`s).
    var isNativeForm: Bool {
        get { self[IsNativeFormKey.self] }
        set { self[IsNativeFormKey.self] = newValue }
    }
}

public extension View {
    /// Marks the view hierarchy (a `Form` or `List`) as native: shared field components render as plain rows.
    func nativeFormRows() -> some View {
        environment(\.isNativeForm, true)
    }

    /// Applies the field card (leading padding, background, rounded corners) outside of a native form;
    /// inside a native form the row gets zero insets and keeps the system row background.
    func fieldCard(isEnabled: Bool = true, leadingPadding: CGFloat = 0) -> some View {
        modifier(FieldCardModifier(isEnabled: isEnabled, leadingPadding: leadingPadding))
    }
}

private struct FieldCardModifier: ViewModifier {
    @Environment(\.isNativeForm) private var isNativeForm

    let isEnabled: Bool
    let leadingPadding: CGFloat

    func body(content: Content) -> some View {
        if isNativeForm {
            content
                .padding(.leading, leadingPadding)
                .listRowInsets(EdgeInsets())
        } else {
            content
                .padding(.leading, leadingPadding)
                .background(
                    isEnabled
                        ? SharedAsset.Colors.backgroundSecondary.swiftUIColor
                        : SharedAsset.Colors.backgroundSecondaryDisabled.swiftUIColor,
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

public extension View {
    /// Inside a native form, removes the row insets (the content pads itself); no-op elsewhere.
    func nativeRowInsetsZero() -> some View {
        modifier(NativeRowInsetsModifier())
    }
}

private struct NativeRowInsetsModifier: ViewModifier {
    @Environment(\.isNativeForm) private var isNativeForm

    func body(content: Content) -> some View {
        if isNativeForm {
            content.listRowInsets(EdgeInsets())
        } else {
            content
        }
    }
}
