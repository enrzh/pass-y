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
/// All state is main-thread only (the call sites are views, processors and coordinators).
enum PassYPerf {
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
    nonisolated(unsafe) static var rowBodyCount = 0

    /// Interval state of the running list load.
    nonisolated(unsafe) private static var listLoadState: OSSignpostIntervalState?

    /// Counts started list loads so a stale timeout does not end a newer interval.
    nonisolated(unsafe) private static var listLoadGeneration = 0

    /// Interval state and start time of the running tap.
    nonisolated(unsafe) private static var tapState: OSSignpostIntervalState?

    /// The start time of the running tap.
    nonisolated(unsafe) private static var tapStart: CFAbsoluteTime = 0

    // MARK: Methods

    /// Starts the "list load" interval (once, until it ends).
    static func beginListLoad() {
        guard listLoadState == nil else { return }
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
    static func endListLoad() {
        guard let state = listLoadState else { return }
        signposter.endInterval("VaultListLoad", state)
        listLoadState = nil
    }

    /// A row appeared on screen.
    static func rowAppeared(_ id: String) {
        endListLoad()
        signposter.emitEvent("RowAppear", "\(id, privacy: .private)")
    }

    /// The user tapped a row or tile.
    static func beginTap(_ kind: StaticString = "row") {
        if let tapState { signposter.endInterval("TapToPush", tapState, "superseded") }
        tapStart = CFAbsoluteTimeGetCurrent()
        tapState = signposter.beginInterval("TapToPush", "\(kind)")
    }

    /// The pushed or presented screen was handed to UIKit.
    static func endTap() {
        guard let state = tapState else { return }
        signposter.endInterval("TapToPush", state)
        tapState = nil
        let milliseconds = (CFAbsoluteTimeGetCurrent() - tapStart) * 1000
        logger.notice("tap_to_push ms=\(milliseconds, format: .fixed(precision: 1))")
    }
}
