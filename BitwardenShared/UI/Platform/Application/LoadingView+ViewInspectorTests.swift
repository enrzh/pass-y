// swiftlint:disable:this file_name
import BitwardenKit
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - LoadingViewTests

class LoadingViewTests: BitwardenTestCase {
    // MARK: Tests

    /// The loading state without a message shows no text.
    @MainActor
    func test_loading_noMessage() throws {
        let subject = LoadingView(
            state: LoadingState<String>.loading(nil),
        ) { data in
            Text(data)
        }
        XCTAssertThrowsError(try subject.inspect().find(ViewType.Text.self))
    }

    /// The loading state shows no spinner and no message in the first frames (no flicker for quick loads).
    @MainActor
    func test_loading_showsNothingAtFirst() throws {
        let subject = LoadingView(
            state: LoadingState<String>.loading(nil),
            loadingMessage: "Loading data…",
        ) { data in
            Text(data)
        }
        XCTAssertThrowsError(try subject.inspect().find(text: "Loading data…"))
        XCTAssertThrowsError(try subject.inspect().find(CircularActivityIndicator.self))
    }

    /// Once visible the indicator shows the message text.
    @MainActor
    func test_delayedIndicator_visible_withMessage() throws {
        let subject = DelayedLoadingIndicator(loadingMessage: "Loading data…", initiallyVisible: true)
        XCTAssertNoThrow(try subject.inspect().find(text: "Loading data…"))
        XCTAssertNoThrow(try subject.inspect().find(CircularActivityIndicator.self))
    }

    /// The delay is short enough to feel immediate for slow loads and long enough to hide quick ones.
    func test_delayedIndicator_delay() {
        XCTAssertGreaterThanOrEqual(DelayedLoadingIndicator.delay, 0.25)
        XCTAssertLessThanOrEqual(DelayedLoadingIndicator.delay, 0.6)
    }

    /// The data state renders the contents view.
    @MainActor
    func test_data_rendersContents() throws {
        let subject = LoadingView(
            state: LoadingState<String>.data("Hello"),
        ) { data in
            Text(data)
        }
        XCTAssertNoThrow(try subject.inspect().find(text: "Hello"))
    }

    /// The error state renders the error view.
    @MainActor
    func test_error_rendersErrorView() throws {
        let subject = LoadingView(
            state: LoadingState<String>.error(errorMessage: "Oops"),
        ) { data in
            Text(data)
        } errorView: { message in
            Text(message)
        }
        XCTAssertNoThrow(try subject.inspect().find(text: "Oops"))
    }
}
