import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - IntroCarouselView

/// A view that allows the user to swipe through the intro carousel and then proceed to creating an
/// account or logging in.
///
struct IntroCarouselView: View {
    // MARK: Properties

    /// An environment variable for getting the vertical size class of the view.
    @Environment(\.verticalSizeClass) var verticalSizeClass

    /// The `Store` for this view.
    @ObservedObject var store: Store<IntroCarouselState, IntroCarouselAction, IntroCarouselEffect>

    // MARK: View

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: store.binding(
                get: \.currentPageIndex,
                send: IntroCarouselAction.currentPageIndexChanged,
            )) {
                ForEachIndexed(store.state.pages) { index, page in
                    pageView(page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.default, value: store.state.currentPageIndex)

            VStack(spacing: 12) {
                AsyncButton {
                    await store.perform(.createAccount)
                } label: {
                    Text(Localizations.createAccount)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                Button {
                    store.send(.logIn)
                } label: {
                    Text(Localizations.logIn)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .controlSize(.large)
                .padding(.vertical, 8)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .multilineTextAlignment(.center)
    }

    /// A dynamic stack view that lays out content vertically when in a regular vertical size class
    /// and horizontally for the compact vertical size class.
    @ViewBuilder
    private func dynamicStackView(
        minHeight: CGFloat,
        @ViewBuilder imageContent: () -> some View,
        @ViewBuilder textContent: () -> some View,
    ) -> some View {
        Group {
            if verticalSizeClass == .regular {
                VStack(spacing: 48) {
                    imageContent()
                    textContent()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: minHeight)
            } else {
                HStack(alignment: .top, spacing: 40) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        imageContent()
                            .padding(.leading, 36)
                            .padding(.vertical, 16)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: minHeight)

                    textContent()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: minHeight)
                }
            }
        }
        .scrollView(
            addVerticalPadding: false,
            backgroundColor: Color(uiColor: .systemBackground),
        )
    }

    /// A view that displays a carousel page.
    @ViewBuilder
    private func pageView(_ page: IntroCarouselState.CarouselPage) -> some View {
        GeometryReader { reader in
            dynamicStackView(minHeight: reader.size.height) {
                page.image
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(
                        width: verticalSizeClass == .regular ? 96 : 80,
                        height: verticalSizeClass == .regular ? 96 : 80,
                    )
                    .accessibilityHidden(true)
            } textContent: {
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.largeTitle.bold())

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Carousel") {
    IntroCarouselView(store: Store(processor: StateProcessor(state: IntroCarouselState())))
}

@available(iOS 17, *)
#Preview("Carousel Landscape", traits: .landscapeRight) {
    IntroCarouselView(store: Store(processor: StateProcessor(state: IntroCarouselState())))
}
#endif
