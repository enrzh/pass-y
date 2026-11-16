import BitwardenKitMocks
import Foundation
import Testing
import UIKit

@testable import BitwardenShared
@testable import BitwardenSharedMocks

// MARK: - CipherIconImageLoaderTests

struct CipherIconImageLoaderTests {
    // MARK: Properties

    var certificateService: MockClientCertificateService
    var errorReporter: MockErrorReporter
    var subject: CipherIconImageLoader

    // MARK: Initialization

    init() {
        certificateService = MockClientCertificateService()
        errorReporter = MockErrorReporter()
        subject = CipherIconImageLoader()
        subject.configure(certificateService: certificateService, errorReporter: errorReporter)
    }

    // MARK: Tests - decodeIcon

    /// The exact 19 x 19 px globe PNG that Vaultwarden 1.37.5 serves for a site without an icon.
    private static let vaultwardenGlobe = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAABMAAAATCAQAAADYWf5HAAABqklEQVR42nWSA6wcYRSFb22bUaM2KIPatm1bc7/7XDtWbdu2bdsO" +
        "a/fP7Dy//XbHJ+dSEqE0xgle84NX7mpRpSQlE7LqHL5zgvHawCpZJz5znW86a0JWSWR8Yc5yO6KaBNCTQSJeLe5yZnzhBCcn+klN" +
        "cYzJH1lEJKIARzSXiObisJ4ekcWXuXAPrD5bNEL3sI5l7LdtnCKPiC+8y8xQ4t9xTlaBJhOyB/4ZO2SQAK3HN1cMxgUJQ4cMuto5" +
        "fzSEEyx2eQRYGUYxYEL6wClO+4nYOI4Jr20pR8YVdOln03m2XNvbGI0TB+V0rTisPq+EH1bFqrDVGrOfRn5m2W1bqC022PeszA/h" +
        "lbYW8WowPqpEEKqXC+XLWWfTRLQB74UTqCSD2RFlE3LdMSF9KDfjsiTD+tNdAtjoxnhSYySqFN+8WpIEzeVyC0AxfmpJEdFZPJ6Q" +
        "WxyM1T3sZh+dE2Rd+cfsYKacsaOWz2uusyQZo/Ny2I6PyZawIXqae1wnT7Ic63OXs8nejcjCTL5x1jyaWRWvueFvzcSBmSQlUaUM" +
        "jvGK7/aUI4x1m5bAf44zwZcVEKqvAAAAAElFTkSuQmCC")!

    /// A PNG of the given square size (not the Vaultwarden file).
    private static func png(size: Int) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.pngData { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    /// The Vaultwarden placeholder globe is "no icon" (`nil`), so the row shows the letter.
    @Test
    func decodeIcon_vaultwardenGlobe_isDiscarded() {
        #expect(UIImage(data: Self.vaultwardenGlobe) != nil) // the fixture is a valid image ...
        #expect(CipherIconImageLoader.decodeIcon(Self.vaultwardenGlobe) == nil) // ... that is discarded
    }

    /// A real favicon is kept, also one that is 19 x 19 px (only the placeholder bytes are discarded).
    @Test
    func decodeIcon_realFavicons_areKept() throws {
        let small = try #require(CipherIconImageLoader.decodeIcon(Self.png(size: 19)))
        #expect(Int(small.size.width * small.scale) == 19) // same size as the placeholder, different file
        #expect(CipherIconImageLoader.decodeIcon(Self.png(size: 16)) != nil)
        #expect(CipherIconImageLoader.decodeIcon(Self.png(size: 64)) != nil)
    }

    /// Bytes that are not an image give `nil`.
    @Test
    func decodeIcon_garbage_isNil() {
        #expect(CipherIconImageLoader.decodeIcon(Data([1, 2, 3])) == nil)
        #expect(CipherIconImageLoader.decodeIcon(Data()) == nil)
    }

    // MARK: Tests - urlSession(_:task:didReceive:)

    /// `urlSession(_:task:didReceive:)` returns `.performDefaultHandling` for challenges that are
    /// not for a client certificate.
    @Test
    func taskDidReceiveChallenge_nonClientCertificate_performsDefaultHandling() async {
        let session = URLSession.shared
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic)

        let (disposition, credential) = await subject.urlSession(session, task: task, didReceive: challenge)

        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    /// `urlSession(_:task:didReceive:)` returns `.performDefaultHandling` when the challenge is
    /// for a client certificate but no identity is available.
    @Test
    func taskDidReceiveChallenge_clientCertificateNoIdentity_performsDefaultHandling() async {
        let session = URLSession.shared
        let task = URLSession.shared.dataTask(with: URL(string: "https://example.com")!)
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        certificateService.getClientCertificateIdentityReturnValue = nil

        let (disposition, credential) = await subject.urlSession(session, task: task, didReceive: challenge)

        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    // MARK: Tests - urlSession(_:didReceive:)

    /// `urlSession(_:didReceive:)` returns `.performDefaultHandling` for challenges that are not
    /// for a client certificate.
    @Test
    func sessionDidReceiveChallenge_nonClientCertificate_performsDefaultHandling() async {
        let session = URLSession.shared
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic)

        let (disposition, credential) = await subject.urlSession(session, didReceive: challenge)

        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    /// `urlSession(_:didReceive:)` returns `.performDefaultHandling` when the challenge is for a
    /// client certificate but no identity is available.
    @Test
    func sessionDidReceiveChallenge_clientCertificateNoIdentity_performsDefaultHandling() async {
        let session = URLSession.shared
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        certificateService.getClientCertificateIdentityReturnValue = nil

        let (disposition, credential) = await subject.urlSession(session, didReceive: challenge)

        #expect(disposition == .performDefaultHandling)
        #expect(credential == nil)
    }

    /// `urlSession(_:didReceive:)` queries the certificate service on a client-certificate
    /// challenge, confirming icon requests participate in mTLS.
    @Test
    func sessionDidReceiveChallenge_clientCertificate_queriesCertificateService() async {
        let session = URLSession.shared
        let challenge = makeChallenge(authenticationMethod: NSURLAuthenticationMethodClientCertificate)
        certificateService.getClientCertificateIdentityReturnValue = nil

        _ = await subject.urlSession(session, didReceive: challenge)

        #expect(certificateService.getClientCertificateIdentityCalled)
    }

    // MARK: Tests - loadImage(from:)

    /// `loadImage(from:)` returns `nil` when `configure` was never called, so the loader fails
    /// closed instead of falling back to a non-mTLS-aware session.
    @Test
    func loadImage_notConfigured_returnsNil() async {
        let unconfigured = CipherIconImageLoader()

        let image = await unconfigured.loadImage(from: URL(string: "https://example.com/icon.png")!)

        #expect(image == nil)
    }

    // MARK: Private

    private func makeChallenge(authenticationMethod: String) -> URLAuthenticationChallenge {
        let protectionSpace = URLProtectionSpace(
            host: "example.com",
            port: 443,
            protocol: "https",
            realm: nil,
            authenticationMethod: authenticationMethod,
        )
        return URLAuthenticationChallenge(
            protectionSpace: protectionSpace,
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: MockAuthenticationChallengeSender(),
        )
    }
}

// MARK: - MockAuthenticationChallengeSender

private class MockAuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}
