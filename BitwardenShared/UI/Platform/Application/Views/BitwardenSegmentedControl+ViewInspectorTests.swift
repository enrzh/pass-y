// swiftlint:disable:this file_name
import BitwardenKit
import SwiftUI
import ViewInspector
import XCTest

@testable import BitwardenShared

class BitwardenSegmentedControlTests: BitwardenTestCase {
    // MARK: Types

    enum Segment: Int, CaseIterable, Identifiable, Menuable {
        case one = 1, two, three

        var id: Int { rawValue }

        var localizedName: String {
            switch self {
            case .one: "One"
            case .two: "Two"
            case .three: "Three"
            }
        }
    }

    // MARK: Tests

}
