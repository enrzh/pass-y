import XCTest

@testable import BitwardenShared

/// Nothing in the shell or the loading indicator can keep the app from idling (formerly `PassYUiR9IdleTests`).
class PassYIdleTests: BitwardenTestCase {
    private func read(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        return try String(contentsOf: url.appendingPathComponent(relative), encoding: .utf8)
    }

    /// The loading indicator has no animation construct and uses the system spinner.
    func test_delayedIndicator_noAnimationConstructs() throws {
        let source = try read("BitwardenShared/UI/Platform/Application/LoadingView.swift")
        let indicator = source.components(separatedBy: "// MARK: - LoadingView").first ?? ""
        XCTAssertFalse(indicator.contains("withAnimation("), "no withAnimation")
        XCTAssertFalse(indicator.contains(".transition("), "no transition")
        XCTAssertFalse(indicator.contains("CircularActivityIndicator"), "no custom repeat-forever spinner")
        XCTAssertTrue(indicator.contains("ProgressView()"))
    }

    /// The fade view disables implicit layer animations.
    @MainActor
    func test_edgeFade_hasNoImplicitAnimations() {
        let fade = PassYEdgeFadeView(edge: .bottom)
        fade.frame = CGRect(x: 0, y: 0, width: 300, height: 120)
        fade.layoutIfNeeded()
        fade.frame = CGRect(x: 0, y: 0, width: 300, height: 140)
        fade.layoutIfNeeded()
        fade.layer.sublayers?.forEach { XCTAssertNil($0.animationKeys(), "no animation on \($0)") }
    }
}

/// The vault home has no system refresh control that can spin for the whole length of a sync (formerly
/// `PassYUiR9NoRefreshControlTests`).
class PassYVaultNoRefreshControlTests: BitwardenTestCase {
    func test_vaultListView_hasNoRefreshable() throws {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 { url.deleteLastPathComponent() }
        let source = try String(
            contentsOf: url.appendingPathComponent("BitwardenShared/UI/Vault/Vault/VaultList/VaultListView.swift"),
            encoding: .utf8,
        )
        XCTAssertFalse(source.contains(".refreshable"), "no pull-to-refresh on the vault home (sync is in the avatar menu)")
        XCTAssertTrue(source.contains("sync: { Task { await store.perform(.refreshVault) } }"), "Sync now stays")
    }
}
