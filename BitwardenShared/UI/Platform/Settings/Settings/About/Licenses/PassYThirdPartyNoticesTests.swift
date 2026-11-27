import XCTest

@testable import BitwardenShared

class PassYThirdPartyNoticesTests: BitwardenTestCase {
    /// The bundled notices load, name what ships (SDK, Introspect, Inter, the SDK's crates) and carry the GPL.
    func test_bundled_loadsShippedComponents() throws {
        let notices = PassYThirdPartyNotices.bundled

        XCTAssertEqual(notices.components.map(\.name), ["Bitwarden SDK", "SwiftUI-Introspect", "Inter"])
        XCTAssertGreaterThan(notices.crates.count, 100)
        XCTAssertTrue(notices.gpl.contains("GNU GENERAL PUBLIC LICENSE"))
        XCTAssertTrue(notices.gpl.contains("Version 3, 29 June 2007"))
        XCTAssertFalse(notices.sdkRevision.isEmpty)

        // Every entry has a licence and at least one licence text.
        for entry in notices.components + notices.crates {
            XCTAssertFalse(entry.license.isEmpty, entry.id)
            XCTAssertFalse(entry.texts.isEmpty, entry.id)
            XCTAssertFalse(notices.text(of: entry.texts).isEmpty, entry.id)
        }

        // Test-only packages do not ship and are not listed.
        let names = Set((notices.components + notices.crates).map(\.name))
        XCTAssertFalse(names.contains("ViewInspector"))
        XCTAssertFalse(names.contains("swift-snapshot-testing"))
        XCTAssertTrue(names.contains("serde"))
    }

    /// The crate list was generated for the SDK revision pinned in project-common.yml.
    func test_sdkRevision_matchesPinnedSDK() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 8 { root.deleteLastPathComponent() }
        let spec = try String(contentsOf: root.appendingPathComponent("project-common.yml"), encoding: .utf8)
        let revision = PassYThirdPartyNotices.bundled.sdkRevision
        XCTAssertTrue(spec.contains("-\(revision)"), "regenerate ThirdPartyNotices.json for the pinned SDK")
    }

    /// `text(of:)` joins several texts and ignores indices out of range.
    func test_textOf() {
        let notices = PassYThirdPartyNotices(sdkRevision: "x", gplText: 0, components: [], crates: [], texts: ["a", "b"])
        XCTAssertEqual(notices.text(of: [0, 1]), "a\n\nb")
        XCTAssertEqual(notices.text(of: [1, 7]), "b")
    }
}
