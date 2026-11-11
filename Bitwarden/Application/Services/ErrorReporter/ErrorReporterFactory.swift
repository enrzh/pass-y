import BitwardenKit
import BitwardenShared

/// A factory to create `ErrorReporter` instances.
///
/// Pass-Y does not send crash reports or telemetry anywhere; errors are only logged locally via OSLog.
enum ErrorReporterFactory {
    // MARK: Static Functions

    /// Creates the default error reporter.
    static func makeDefaultErrorReporter() -> ErrorReporter {
        OSLogErrorReporter()
    }
}
