import BitwardenKit
import CryptoKit
import Foundation
import UIKit

// MARK: - CipherIconImageLoader

/// A singleton that downloads vault item icons through a `URLSession` that participates in mTLS —
/// forwarding client-certificate challenges to `ClientCertificateService` the same way API
/// requests do via `CertificateHTTPClient`.
///
/// Singleton to share a single URLSession across all icon loads and avoid threading the loader
/// through the VaultListItemRow view stack. `configure(certificateService:errorReporter:)` is
/// called once by `ServiceContainer` before any view loads.
///
final class CipherIconImageLoader: NSObject, @unchecked Sendable {
    // MARK: Properties

    /// The shared instance configured by `ServiceContainer` at app/extension startup.
    static let shared = CipherIconImageLoader()

    /// The service used to resolve the user's client certificate identity for mTLS challenges.
    private var certificateService: ClientCertificateService?

    /// The service used to report non-fatal errors, including misconfiguration of this loader.
    private var errorReporter: ErrorReporter?

    /// The session used to download icons. Defaults to `URLSession.shared` until `configure` is
    /// called, at which point it is replaced with a session whose delegate is `self`.
    private var urlSession: URLSession = .shared

    /// Decoded icons by URL: scrolling back over a row must not download, hash and decode its icon again.
    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    /// Protects `inFlight` and the cache writes.
    private let lock = NSLock()

    /// Running downloads by URL, shared by rows that show the same icon.
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    // MARK: Methods

    /// Configures the loader with the services needed to participate in mTLS and report errors.
    /// Must be called once at startup before any icon loads.
    ///
    /// - Parameters:
    ///   - certificateService: The service used to resolve the user's client certificate.
    ///   - errorReporter: The service used to report non-fatal errors.
    ///
    func configure(certificateService: ClientCertificateService, errorReporter: ErrorReporter) {
        self.certificateService = certificateService
        self.errorReporter = errorReporter
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    /// Downloads and decodes the icon at the given URL.
    ///
    /// - Parameter url: The icon URL.
    /// - Returns: The decoded image, or `nil` if the loader is not configured, the request failed,
    ///   or the response was non-2xx. Callers should fall back to a placeholder on `nil`.
    ///
    func loadImage(from url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        let task: Task<UIImage?, Never> = lock.withLock {
            if let running = inFlight[url] { return running }
            // Unstructured on purpose: scrolling a row away cancels its caller, not the download other rows share.
            let created = Task.detached(priority: .utility) { [self] in
                let image = await download(url)
                lock.withLock {
                    if let image {
                        cache.setObject(image, forKey: url as NSURL, cost: Int(image.size.width * image.size.height))
                    }
                    inFlight[url] = nil
                }
                return image
            }
            inFlight[url] = created
            return created
        }
        return await task.value
    }

    /// The decoded icon if it was loaded before (synchronous, so a row that scrolls back shows it immediately).
    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Downloads, decodes and prepares the icon off the main thread.
    private func download(_ url: URL) async -> UIImage? {
        guard certificateService != nil else {
            errorReporter?.log(error: BitwardenError.generalError(
                type: "CipherIconImageLoader",
                message: "`configure(certificateService:errorReporter:)` must be called before loading icons.",
            ))
            return nil
        }
        do {
            let (data, response) = try await urlSession.data(from: url)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                return nil
            }
            // `UIImage(data:)` decodes lazily on first draw (on the main thread, while scrolling). Decode now.
            let image = Self.decodeIcon(data)
            return await image?.byPreparingForDisplay() ?? image
        } catch {
            return nil
        }
    }

    /// SHA-256 of the generic globe PNG (19 x 19 px, 483 bytes) that Vaultwarden 1.37.x answers with when a site
    /// has no icon (fetched from `/icons/<unknown host>/icon.png`).
    static let vaultwardenPlaceholderSHA256s: Set<String> = [
        "01d7ddb3c3c46ca24f7d911abd32849aa19627c8be515273bdfb98100460aacb",
    ]

    /// Decodes icon bytes; returns `nil` for undecodable data and for the server's generic placeholder globe,
    /// so the row shows the letter icon (Apple Passwords) instead.
    ///
    /// The placeholder is recognised by its exact bytes (SHA-256), not by its 19 x 19 size: a real small favicon
    /// of that size is a different file and is kept. Choice and limit: another server version with a different
    /// placeholder file would show its globe until its hash is added here.
    ///
    static func decodeIcon(_ data: Data) -> UIImage? {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if vaultwardenPlaceholderSHA256s.contains(digest) { return nil }
        return UIImage(data: data)
    }

    // MARK: Private

    /// Handles a `URLAuthenticationChallenge` by providing the user's client certificate when
    /// available, or deferring to default handling for other challenge types.
    ///
    /// - Parameter challenge: The authentication challenge to handle.
    /// - Returns: A disposition and optional credential to apply to the challenge.
    ///
    private func handle(
        _ challenge: URLAuthenticationChallenge,
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            guard let identity = await certificateService?.getClientCertificateIdentity() else {
                return (.performDefaultHandling, nil)
            }
            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            return (.useCredential, credential)

        default:
            return (.performDefaultHandling, nil)
        }
    }
}

// MARK: - URLSessionDelegate

extension CipherIconImageLoader: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await handle(challenge)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        await handle(challenge)
    }
}
