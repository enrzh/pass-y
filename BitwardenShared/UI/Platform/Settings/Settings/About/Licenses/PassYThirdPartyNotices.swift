import Foundation
import OSLog

// MARK: - PassYThirdPartyNotices

/// The licence notices of the software that ships in the app besides Pass-Y's own code, read from
/// `ThirdPartyNotices.json` (written by `Scripts-passy/generate_third_party_notices.py`). Licence texts are stored once
/// and referenced by index.
///
struct PassYThirdPartyNotices: Decodable, Equatable {
    // MARK: Types

    /// A component (Swift package, binary, font) or a Rust crate inside the SDK.
    struct Entry: Decodable, Equatable, Identifiable {
        /// The name.
        let name: String

        /// The version (may be empty).
        let version: String

        /// The licence (SPDX expression).
        let license: String

        /// The project page, if any.
        var url: URL?

        /// The indices of the licence texts in `texts`.
        let texts: [Int]

        var id: String { "\(name) \(version)" }

        /// The name with the version.
        var title: String { version.isEmpty ? name : "\(name) \(version)" }
    }

    // MARK: Static

    /// The notices bundled with the app (empty if the resource is missing or broken).
    static let bundled: PassYThirdPartyNotices = {
        let bundle = Bundle(for: BitwardenSharedBundleToken.self)
        guard let url = bundle.url(forResource: "ThirdPartyNotices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let notices = try? JSONDecoder().decode(PassYThirdPartyNotices.self, from: data) else {
            Logger.application.error("Pass-Y licences: ThirdPartyNotices.json missing or unreadable")
            return PassYThirdPartyNotices(sdkRevision: "", gplText: 0, components: [], crates: [], texts: [])
        }
        return notices
    }()

    // MARK: Properties

    /// The sdk-internal revision the crate list was generated for.
    let sdkRevision: String

    /// The index of the GNU GPL v3 text (Pass-Y's own licence) in `texts`.
    let gplText: Int

    /// The components (SDK, Swift packages, fonts).
    let components: [Entry]

    /// The Rust crates compiled into the SDK.
    let crates: [Entry]

    /// The licence texts.
    let texts: [String]

    // MARK: Methods

    /// The texts of an entry, joined (an entry under several licences shows all of them).
    func text(of indices: [Int]) -> String {
        indices.filter(texts.indices.contains).map { texts[$0] }.joined(separator: "\n\n")
    }

    /// The text of the GNU GPL v3.
    var gpl: String { text(of: [gplText]) }
}

// MARK: - BitwardenSharedBundleToken

/// A class of this framework, to find its bundle.
private final class BitwardenSharedBundleToken {}
