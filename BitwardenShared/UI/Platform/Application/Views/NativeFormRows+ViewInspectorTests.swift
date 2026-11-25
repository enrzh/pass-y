import BitwardenKit
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

// MARK: - NativeFormRowsTests

class NativeFormRowsTests: BitwardenTestCase {
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
