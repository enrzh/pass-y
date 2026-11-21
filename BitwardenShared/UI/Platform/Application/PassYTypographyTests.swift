import BitwardenKit
import SwiftUI
import XCTest

@testable import BitwardenShared

// MARK: - PassYTypographyTests

/// ui-r8: system typography everywhere (Apple text styles, no fixed point sizes or custom fonts).
final class PassYTypographyTests: BitwardenTestCase {
    /// The repository root, found from this file (`<root>/BitwardenShared/UI/Platform/Application/...`).
    private var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1, !FileManager.default.fileExists(atPath: url.appendingPathComponent("BitwardenKit").path) {
            url.deleteLastPathComponent()
        }
        return url
    }

    /// Production Swift files of the app and the kit (tests, previews and generated files excluded).
    private func productionSources() -> [URL] {
        let root = repositoryRoot
        var files: [URL] = []
        for folder in ["BitwardenShared", "BitwardenKit", "Bitwarden"] {
            let base = root.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                let name = file.lastPathComponent
                if name.contains("Tests") || name.contains("Fixtures") || file.path.contains("/Generated/")
                    || file.path.contains("/TestHelpers/") || file.path.contains("/PreviewContent/") {
                    continue
                }
                files.append(file)
            }
        }
        return files
    }

    /// No fixed font sizes or custom fonts in the production sources: every font is a text style (scales with
    /// Dynamic Type) or derived from one.
    func test_noFixedFontSizesOrCustomFonts() throws {
        let forbidden = try [
            NSRegularExpression(pattern: #"\.system\(size:"#),
            NSRegularExpression(pattern: #"\.custom\(""#),
            NSRegularExpression(pattern: #"UIFont\(name:"#),
            NSRegularExpression(pattern: #"UIFont\.systemFont\(ofSize: *[0-9]"#),
            NSRegularExpression(pattern: #"UIFont\.monospacedSystemFont\(ofSize: *[0-9]"#),
        ]
        let files = productionSources()
        XCTAssertGreaterThan(files.count, 500, "the scan found the sources (\(repositoryRoot.path))")
        var offenders: [String] = []
        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for (index, line) in text.components(separatedBy: "\n").enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                if forbidden.contains(where: { $0.firstMatch(in: line, range: range) != nil }) {
                    offenders.append("\(file.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertEqual(offenders, [], "fixed sizes or custom fonts found")
    }

    /// The style guide maps to the Apple text styles.
    func test_styleGuideUsesAppleTextStyles() {
        XCTAssertEqual(StyleGuideFont.body.textStyle, .body)
        XCTAssertEqual(StyleGuideFont.headline.textStyle, .headline)
        XCTAssertEqual(StyleGuideFont.callout.textStyle, .callout)
        XCTAssertEqual(StyleGuideFont.subheadline.textStyle, .subheadline)
        XCTAssertEqual(StyleGuideFont.footnote.textStyle, .footnote)
        XCTAssertEqual(StyleGuideFont.caption1.textStyle, .caption)
        XCTAssertEqual(StyleGuideFont.caption2.textStyle, .caption2)
        XCTAssertEqual(StyleGuideFont.title.textStyle, .title)
        XCTAssertEqual(StyleGuideFont.title2.textStyle, .title2)
        XCTAssertEqual(StyleGuideFont.title3.textStyle, .title3)
        XCTAssertEqual(StyleGuideFont.largeTitle.textStyle, .largeTitle)
        XCTAssertEqual(StyleGuideFont.sensitiveInfoSmall.textStyle, .footnote, "no Menlo: system monospaced footnote")
    }

    /// The system default appearance is used for bars and segmented controls (no custom fonts or colors).
    @MainActor
    func test_appearancesDoNotOverrideSystemFonts() {
        UI.applyDefaultAppearances()
        XCTAssertNil(UINavigationBar.appearance().standardAppearance.largeTitleTextAttributes[.font])
        XCTAssertNil(UINavigationBar.appearance().standardAppearance.titleTextAttributes[.font])
        XCTAssertNil(UISegmentedControl.appearance().titleTextAttributes(for: .normal)?[.font])
    }
}
