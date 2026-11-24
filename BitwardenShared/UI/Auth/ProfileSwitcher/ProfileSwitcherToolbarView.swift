import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - ProfileSwitcherToolbarView

/// A view that allows the user to view, select, and add profiles.
///
struct ProfileSwitcherToolbarView: View {
    /// The `Store` for this view.
    @ObservedObject var store: Store<ProfileSwitcherState, ProfileSwitcherAction, ProfileSwitcherEffect>

    var body: some View {
        profileSwitcherToolbarItem
    }

    /// The Toolbar item for the profile switcher view
    @ViewBuilder var profileSwitcherToolbarItem: some View {
        let tintColor = store.state.showPlaceholderToolbarIcon
            ? nil
            : store.state.activeAccountProfile?.color

        AsyncButton {
            await store.perform(.requestedProfileSwitcher(visible: !store.state.isVisible))
        } label: {
            // The tint color on Liquid Glass gives the button its color (no icon background color).
            profileSwitcherIcon(
                color: nil,
                initials: store.state.showPlaceholderToolbarIcon
                    ? nil
                    : store.state.activeAccountProfile?.userInitials,
                textColor: store.state.showPlaceholderToolbarIcon
                    ? nil
                    : store.state.activeAccountProfile?.profileIconTextColor,
                size: .toolbar,
            )
        }
        .buttonStyle(.glassProminent)
        .tint(tintColor ?? SharedAsset.Colors.backgroundTertiary.swiftUIColor)
        // Removes the extra padding around the button, so the initials can scale larger without widening it.
        .padding(.horizontal, -4)
        .accessibilityIdentifier("CurrentActiveAccount")
        .accessibilityLabel(Localizations.account)
        .hidden(!store.state.showPlaceholderToolbarIcon && store.state.accounts.isEmpty)
    }
}

extension View {
    /// An icon for a profile switcher item.
    ///
    /// - Parameters:
    ///   - color: The color of the icon.
    ///   - initials: The initials for the icon.
    ///   - textColor: The text color for the icon.
    ///   - size: The size configuration for the icon.
    ///
    @ViewBuilder
    func profileSwitcherIcon(
        color: Color? = SharedAsset.Colors.backgroundTertiary.swiftUIColor,
        initials: String?,
        textColor: Color?,
        size: ProfileSwitcherIconSize = .standard,
    ) -> some View {
        Text(initials ?? "  ")
            .styleGuide(size.textStyle, weight: size.fontWeight)
            .padding(size.padding)
            .frame(minWidth: 22, alignment: .center)
            .background {
                if initials == nil {
                    SharedAsset.Icons.horizontalDots16.swiftUIImage
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .opacity(initials == nil ? 1.0 : 0.0)
                        .accessibilityHidden(initials != nil)
                }
            }
            .foregroundColor(textColor ?? SharedAsset.Colors.textInteraction.swiftUIColor)
            .background(color)
            .if(size.shouldClipToCircle) { view in
                view.clipShape(Circle())
            }
    }
}

// MARK: - ProfileSwitcherIconSize

/// Size configurations for profile switcher icons.
///
struct ProfileSwitcherIconSize {
    // MARK: Properties

    /// The font weight for the user's initials.
    let fontWeight: SwiftUI.Font.Weight

    /// The padding to apply to the user's initials.
    let padding: CGFloat

    /// The text style for the user's initials.
    let textStyle: StyleGuideFont

    /// Whether the user's initials and background should be clipped to a circle.
    let shouldClipToCircle: Bool
}

extension ProfileSwitcherIconSize {
    /// The standard icon size for the profile switcher and toolbar pre-iOS 26.
    static let standard = ProfileSwitcherIconSize(
        fontWeight: .regular,
        padding: 4,
        textStyle: .caption2Monospaced,
        shouldClipToCircle: true,
    )

    /// A larger icon size for use as a toolbar icon on iOS 26+.
    static let toolbar = ProfileSwitcherIconSize(
        fontWeight: .semibold,
        padding: 0,
        textStyle: .bodyMonospaced,
        shouldClipToCircle: false,
    )
}

// MARK: Previews

#if DEBUG
#Preview("Empty") {
    NavigationView {
        Spacer()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileSwitcherToolbarView(
                        store: Store(
                            processor: StateProcessor(
                                state: .empty(),
                            ),
                        ),
                    )
                }
            }
    }
}

#Preview("No Active") {
    NavigationView {
        Spacer()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileSwitcherToolbarView(
                        store: Store(
                            processor: StateProcessor(
                                state: .init(
                                    accounts: [.anneAccount],
                                    activeAccountId: nil,
                                    allowLockAndLogout: true,
                                    isVisible: false,
                                ),
                            ),
                        ),
                    )
                }
            }
    }
}

#Preview("Single Account") {
    NavigationView {
        Spacer()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileSwitcherToolbarView(
                        store: Store(
                            processor: StateProcessor(
                                state: .singleAccount,
                            ),
                        ),
                    )
                }
            }
    }
}

#Preview("Dual Account") {
    NavigationView {
        Spacer()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileSwitcherToolbarView(
                        store: Store(
                            processor: StateProcessor(
                                state: ProfileSwitcherState(
                                    accounts: [
                                        .anneAccount,
                                        .fixture(color: .green, userId: "1", userInitials: "BB"),
                                    ],
                                    activeAccountId: "1",
                                    allowLockAndLogout: true,
                                    isVisible: false,
                                ),
                            ),
                        ),
                    )
                }
            }
    }
}
#endif
