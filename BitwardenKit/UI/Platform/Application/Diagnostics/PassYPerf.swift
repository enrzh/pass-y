#if DEBUG
import Foundation
import os

// MARK: - PassYPerf

/// Signposts and counters for the responsiveness work (ui-r8). Intervals and events show up in Instruments
/// (category "perf") and can be asserted by `XCTOSSignpostMetric` in the UI perf tests.
///
/// - `VaultListLoad`: the list received its data until the first row appeared.
/// - `RowAppear`: a row appeared (event, id as metadata).
/// - `TapToPush`: a row (or tile) was tapped until the pushed or presented screen was handed to UIKit.
///
/// - `Startup` (event): a named step of launch and unlock (`mark`), logged with the absolute time so a UI test (same
///   host clock in the simulator) can split "Face ID match -> first row" into its steps.
///
/// - `nav.<step>` marks and the `frameprobe` line of a push/pop come from `PassYNavigationProbe`.
///
/// All state is main-thread only (the call sites are views, processors and coordinators). DEBUG only (ui-r9): the
/// whole type and every call site are inside `#if DEBUG`, so the release build contains no signposts, counters, log
/// strings or symbols. All Pass-Y diagnostics live in this `Diagnostics` folder.
public enum PassYPerf {
    // MARK: Constants

    /// The subsystem of all signposts.
    static let subsystem = "de.aiity.passy"

    /// The category of all signposts.
    static let category = "perf"

    // MARK: Properties

    /// The signposter.
    static let signposter = OSSignposter(subsystem: subsystem, category: category)

    /// The logger for numbers that are not signposts (tap latency in milliseconds).
    static let logger = Logger(subsystem: subsystem, category: category)

    /// How many row bodies were evaluated (test counter).
    nonisolated(unsafe) public static var rowBodyCount = 0

    /// How many rows were built by the list builders (test counter; before ui-r8 every build created a child store).
    nonisolated(unsafe) public static var rowBuildCount = 0

    /// How many cell bodies were evaluated (test counter).
    nonisolated(unsafe) public static var cellBodyCount = 0

    /// Interval state of the running list load.
    nonisolated(unsafe) private static var listLoadState: OSSignpostIntervalState?

    /// Counts started list loads so a stale timeout does not end a newer interval.
    nonisolated(unsafe) private static var listLoadGeneration = 0

    /// Interval state and start time of the running tap.
    nonisolated(unsafe) private static var tapState: OSSignpostIntervalState?

    /// The start time of the running tap.
    nonisolated(unsafe) private static var tapStart: CFAbsoluteTime = 0

    // MARK: Methods

    /// A named step of launch, unlock and the first vault frame (`startup mark=<name> t=<absolute seconds>`).
    public static func mark(_ name: String) {
        let now = CFAbsoluteTimeGetCurrent()
        signposter.emitEvent("Startup", "\(name, privacy: .public)")
        logger.notice("startup mark=\(name, privacy: .public) t=\(now, format: .fixed(precision: 3), privacy: .public)")
    }

    /// Starts the "list load" interval (once, until it ends).
    public static func beginListLoad() {
        guard listLoadState == nil else { return }
        mark("listData")
        listLoadState = signposter.beginInterval("VaultListLoad")
        listLoadGeneration += 1
        let generation = listLoadGeneration
        // A later emission that changes no visible row never produces a new `onAppear`; close the interval then.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard listLoadGeneration == generation, let state = listLoadState else { return }
            signposter.endInterval("VaultListLoad", state, "no row appeared")
            listLoadState = nil
        }
    }

    /// Ends the "list load" interval when the first row appeared.
    public static func endListLoad() {
        guard let state = listLoadState else { return }
        mark("firstRow")
        signposter.endInterval("VaultListLoad", state)
        listLoadState = nil
    }

    /// A row appeared on screen.
    public static func rowAppeared(_ id: String) {
        endListLoad()
        signposter.emitEvent("RowAppear", "\(id, privacy: .private)")
    }

    /// The user tapped a row or tile.
    public static func beginTap(_ kind: StaticString = "row") {
        if let tapState { signposter.endInterval("TapToPush", tapState, "superseded") }
        tapStart = CFAbsoluteTimeGetCurrent()
        tapState = signposter.beginInterval("TapToPush", "\(kind)")
    }

    /// The pushed or presented screen was handed to UIKit.
    public static func endTap() {
        guard let state = tapState else { return }
        signposter.endInterval("TapToPush", state)
        tapState = nil
        let milliseconds = (CFAbsoluteTimeGetCurrent() - tapStart) * 1000
        logger.notice("tap_to_push ms=\(milliseconds, format: .fixed(precision: 1))")
    }
}
#endif
