import BitwardenKit
import BitwardenKitMocks
import SwiftUI
import XCTest

@testable import BitwardenShared

// MARK: - VaultListItemRowAccessibilityTests

/// ui-r8: the UI tests (and VoiceOver users of identifiers) find the row button as `VaultListItemRowButton`. A UI test
/// tree dump showed that a button as wide as the row was merged with the row container and carried the container's
/// identifier (`CipherCell`) instead. This test reads the real accessibility tree of a hosted row.
final class VaultListItemRowAccessibilityTests: BitwardenTestCase {
    /// All accessibility identifiers below `object` (SwiftUI exposes its nodes through `accessibilityElements`).
    @MainActor
    private func identifiers(in object: Any, depth: Int = 0) -> [String] {
        guard depth < 12, let object = object as? NSObject else { return [] }
        var result: [String] = []
        if let id = object.accessibilityIdentifier, !id.isEmpty { result.append(id) }
        var children: [Any] = object.accessibilityElements ?? []
        if children.isEmpty, let view = object as? UIView { children = view.subviews }
        if children.isEmpty {
            for index in 0 ..< max(0, object.accessibilityElementCount()) {
                if let child = object.accessibilityElement(at: index) { children.append(child) }
            }
        }
        for child in children { result += identifiers(in: child, depth: depth + 1) }
        return result
    }

    @MainActor
    func test_rowButtonAndRowIdentifier_bothInAccessibilityTree() throws {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("no window scene")
        }
        let cell = VaultListRowCell(
            state: VaultListItemRowState(item: .fixture(), hasDivider: true, showWebIcons: true),
            perform: { _ in },
            send: { _ in },
            timeProvider: MockTimeProvider(.mockTime(Date(year: 2023, month: 12, day: 31))),
            onDelete: nil,
        )
        let host = UIHostingController(rootView: List { cell.equatable().listRowInsets(EdgeInsets()) }.listStyle(.plain))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let ids = identifiers(in: host.view as Any)
        window.isHidden = true
        XCTAssertTrue(ids.contains("VaultListItemRowButton"), "row button identifier present: \(ids)")
        XCTAssertTrue(ids.contains("CipherCell"), "row container identifier present: \(ids)")
    }
}
