import BitwardenKit
import BitwardenResources
import SwiftUI

// MARK: - LicensesPage

/// The pages of About > Licenses.
public enum LicensesPage: Hashable {
    /// Pass-Y's licence, the source code and the third-party components.
    case overview

    /// The Rust crates compiled into the SDK.
    case crates

    /// A licence text.
    ///
    /// - Parameters:
    ///   - title: The title of the page.
    ///   - texts: The indices of the texts in `PassYThirdPartyNotices.texts`.
    ///
    case text(title: String, texts: [Int])
}

// MARK: - LicensesView

/// About > Licenses: Pass-Y's GPLv3 notice and source code, and the notices of the third-party software in the app.
///
struct LicensesView: View {
    // MARK: Properties

    /// The notices.
    let notices: PassYThirdPartyNotices

    /// Opens another licences page.
    let open: (LicensesPage) -> Void

    /// Opens a URL.
    @Environment(\.openURL) private var openURL

    // MARK: View

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: PassYDesign.Spacing.small) {
                    Text(verbatim: "Pass-Y © 2026 aiity")
                        .font(.headline)
                    Text(Localizations.passYLicenseNotice)
                        .font(.subheadline)
                    Text(Localizations.basedOnBitwardenIOS)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, PassYDesign.Spacing.xSmall)
                .accessibilityElement(children: .combine)

                PassYSettingsRow(
                    Localizations.sourceCode,
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    tint: .gray,
                    accessory: .external,
                    identifier: "LicensesSourceCodeButton",
                ) {
                    openURL(ExternalLinksConstants.sourceCode)
                }

                PassYSettingsRow(
                    Localizations.gnuGeneralPublicLicenseV3,
                    systemImage: "doc.text.fill",
                    tint: .blue,
                    identifier: "LicensesGPLButton",
                ) {
                    open(.text(title: Localizations.gnuGeneralPublicLicenseV3, texts: [notices.gplText]))
                }
            }

            Section {
                ForEach(notices.components) { component in
                    PassYSettingsRow(
                        component.title,
                        systemImage: "shippingbox.fill",
                        tint: .indigo,
                        value: component.license.components(separatedBy: " ").first,
                    ) {
                        open(.text(title: component.name, texts: component.texts))
                    }
                }

                PassYSettingsRow(
                    Localizations.rustLibrariesInTheSDK,
                    systemImage: "square.stack.3d.up.fill",
                    tint: .orange,
                    value: "\(notices.crates.count)",
                    identifier: "LicensesCratesButton",
                ) {
                    open(.crates)
                }
            } header: {
                Text(Localizations.thirdPartySoftware)
            } footer: {
                PassYSectionFooter(Localizations.thirdPartySoftwareFooter)
            }
        }
        .navigationBar(title: Localizations.softwareLicenses, titleDisplayMode: .inline)
    }
}

// MARK: - LicenseCratesView

/// The Rust crates compiled into the SDK, each with its licence.
///
struct LicenseCratesView: View {
    /// The notices.
    let notices: PassYThirdPartyNotices

    /// Opens a licence text.
    let open: (LicensesPage) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(notices.crates) { crate in
                    PassYSettingsRow(crate.title, value: crate.license) {
                        open(.text(title: crate.title, texts: crate.texts))
                    }
                }
            } footer: {
                PassYSectionFooter(Localizations.rustLibrariesFooter(notices.sdkRevision))
            }
        }
        .navigationBar(title: Localizations.rustLibrariesInTheSDK, titleDisplayMode: .inline)
    }
}

// MARK: - LicenseTextView

/// A licence text, in paragraphs (a long text such as the GPL stays fast to scroll).
///
struct LicenseTextView: View {
    /// The title.
    let title: String

    /// The text.
    let text: String

    /// The paragraphs of the text.
    private var paragraphs: [String] {
        text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PassYDesign.Spacing.medium) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(verbatim: paragraph)
                        .font(.footnote.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .textSelection(.enabled)
            .padding(PassYDesign.Spacing.large)
        }
        .passYGroupedBackground()
        .navigationBar(title: title, titleDisplayMode: .inline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    NavigationStack {
        LicensesView(notices: .bundled) { _ in }
    }
}
#endif
