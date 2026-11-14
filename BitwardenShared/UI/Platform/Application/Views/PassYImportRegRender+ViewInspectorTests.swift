// swiftlint:disable:this file_name
import BitwardenKit
import BitwardenResources
import SwiftUI
import UIKit
import XCTest

@testable import BitwardenShared

/// Renders the rewritten Import/Export, registration and 2FA screens in light and dark mode to PNG files when the
/// directory `/tmp/passy-ir-shots` exists (no-op otherwise). Used for the screenshot evidence of the rewrite.
@MainActor
final class PassYImportRegRenderTests: BitwardenTestCase {
    private let directory = "/tmp/passy-ir-shots"

    private func render(_ name: String, _ view: some View, size: CGSize = CGSize(width: 393, height: 852)) throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: directory), "no screenshot directory")
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let host = UIHostingController(rootView: NavigationView { view }.navigationViewStyle(.stack))
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(origin: .zero, size: size))
            window.frame = CGRect(origin: .zero, size: size)
            window.overrideUserInterfaceStyle = style
            window.rootViewController = host
            window.makeKeyAndVisible()
            RunLoop.main.run(until: Date().addingTimeInterval(2.5))
            host.view.frame = window.bounds
            host.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                if !host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) {
                    host.view.layer.render(in: context.cgContext)
                }
            }
            try image.pngData()?.write(to: URL(fileURLWithPath: "\(directory)/\(name)-\(suffix).png"))
            window.isHidden = true
        }
    }

    func test_renderAll() throws {
        try render("2fa-email", TwoFactorAuthView(store: Store(processor: StateProcessor(
            state: TwoFactorAuthState(authMethod: .email, displayEmail: "pa***@example.test"),
        ))))
        try render("2fa-duo", TwoFactorAuthView(store: Store(processor: StateProcessor(
            state: TwoFactorAuthState(authMethod: .duo),
        ))))
        try render("reg-start", StartRegistrationView(store: Store(processor: StateProcessor(
            state: StartRegistrationState(),
        ))))
        try render("reg-complete", CompleteRegistrationView(store: Store(processor: StateProcessor(
            state: CompleteRegistrationState(
                emailVerificationToken: "token",
                userEmail: "example@example.test",
            ),
        ))))
        try render("export-settings", ExportSettingsView(store: Store(processor: StateProcessor())))
        try render("export-vault", ExportVaultView(store: Store(processor: StateProcessor(
            state: ExportVaultState(),
        ))))
        var encrypted = ExportVaultState()
        encrypted.fileFormat = .jsonEncrypted
        try render("export-vault-encrypted", ExportVaultView(store: Store(processor: StateProcessor(state: encrypted))))
        try render("export-cxf", ExportCXFView(store: Store(processor: StateProcessor(
            state: ExportCXFState(status: .prepared(itemsToExport: [
                CXFCredentialsResult(count: 13, type: .password),
                CXFCredentialsResult(count: 7, type: .passkey),
            ])),
        ))))
        try render("import-cxf", ImportCXFView(store: Store(processor: StateProcessor(
            state: ImportCXFState(status: .success(totalImportedCredentials: 20, importedResults: [
                CXFCredentialsResult(count: 13, type: .password),
                CXFCredentialsResult(count: 7, type: .passkey),
            ])),
        ))))
        for (name, page) in [("intro", ImportLoginsState.Page.intro), ("step1", .step1), ("step3", .step3)] {
            try render("import-logins-\(name)", ImportLoginsView(store: Store(processor: StateProcessor(
                state: ImportLoginsState(mode: .vault, page: page),
            ))))
        }
        try render("import-success", ImportLoginsSuccessView(store: Store(processor: StateProcessor())))
    }
}
