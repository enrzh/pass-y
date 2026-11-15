import BitwardenResources
import SwiftUI

// MARK: - IntroCarouselState

/// An object that defines the current state of a `IntroCarouselView`.
///
struct IntroCarouselState: Equatable {
    // MARK: Types

    /// A model representing the data to display on a single page in the carousel.
    ///
    struct CarouselPage: Equatable, Identifiable {
        // MARK:

        /// A unique identifier of the page.
        let id: String = UUID().uuidString

        /// An image to display.
        let image: Image

        /// A message to display on the page.
        let message: String

        /// A title to display on the page.
        let title: String
    }

    // MARK: Properties

    /// The index of the currently visible page in the carousel.
    var currentPageIndex = 0

    /// The list of scrollable pages displayed in the carousel.
    let pages: [CarouselPage] = [
        CarouselPage(
            image: Image(systemName: "lock.shield.fill"),
            message: Localizations.introCarouselPage1Message,
            title: Localizations.introCarouselPage1Title,
        ),

        CarouselPage(
            image: Image(systemName: "faceid"),
            message: Localizations.introCarouselPage2Message,
            title: Localizations.introCarouselPage2Title,
        ),

        CarouselPage(
            image: Image(systemName: "wand.and.stars"),
            message: Localizations.introCarouselPage3Message,
            title: Localizations.introCarouselPage3Title,
        ),

        CarouselPage(
            image: Image(systemName: "macbook.and.iphone"),
            message: Localizations.introCarouselPage4Message,
            title: Localizations.introCarouselPage4Title,
        ),
    ]
}
