import BitwardenKit
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - NativeSetupSectionTests

class NativeSetupSectionTests: BitwardenTestCase {
    // MARK: Properties

    var performed: [String] = []

    // MARK: Setup & Teardown

    override func setUp() {
        super.setUp()
        performed = []
    }

    // MARK: Tests

    /// The section is a native `Section` with headline, message and rows; tapping the rows runs their actions.
    @MainActor
    func test_rows_tap() async throws {
        let subject = NativeSetupSection(
            title: "Headline",
            message: "Message",
            action: NativeSetupSection.Row(title: "Turn on") { self.performed.append("action") },
            secondary: NativeSetupSection.Row(title: "Learn more") { self.performed.append("secondary") },
            dismiss: NativeSetupSection.Row(title: "Dismiss") { self.performed.append("dismiss") },
        )
        XCTAssertNoThrow(try subject.inspect().find(ViewType.Section.self))
        XCTAssertNoThrow(try subject.inspect().find(text: "Message"))
        try await subject.inspect().find(asyncButton: "Turn on").tap()
        try await subject.inspect().find(asyncButton: "Learn more").tap()
        try await subject.inspect().find(asyncButton: "Dismiss").tap()
        XCTAssertEqual(performed, ["action", "secondary", "dismiss"])
    }

    /// Without secondary and dismiss rows only the action row exists (no card, no badge).
    @MainActor
    func test_optionalRows_hidden() throws {
        let subject = NativeSetupSection(
            title: "Headline",
            action: NativeSetupSection.Row(title: "Get started") {},
        )
        XCTAssertNoThrow(try subject.inspect().find(asyncButton: "Get started"))
        XCTAssertThrowsError(try subject.inspect().find(asyncButton: "Dismiss"))
    }

    /// In a native form, `SectionView` renders a real `Section` and `ContentBlock` renders its children as rows.
    @MainActor
    func test_sectionViewAndContentBlock_nativeFormRendersSection() throws {
        let view = Form {
            SectionView("Title") {
                ContentBlock {
                    Text("A")
                    Text("B")
                }
            }
        }
        .nativeFormRows()
        let inspected = try view.inspect()
        XCTAssertNoThrow(try inspected.find(ViewType.Section.self))
        XCTAssertNoThrow(try inspected.find(text: "A"))
        XCTAssertNoThrow(try inspected.find(text: "B"))
    }
}

// MARK: - InspectableView + NativeSetupSection

extension InspectableView {
    /// Finds the `Section` of a `NativeSetupSection` by its headline (the `Label` title).
    func find(setupSection title: String) throws -> InspectableView<ViewType.Section> {
        try find(ViewType.Section.self) { section in
            ((try? section.find(ViewType.Label.self).title().text().string()) ?? nil) == title
        }
    }
}
