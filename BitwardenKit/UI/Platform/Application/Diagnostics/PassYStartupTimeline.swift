#if DEBUG
import Darwin
import Foundation
import QuartzCore
import UIKit

// MARK: - PassYStartupTimeline

/// DEBUG only: a startup / activation timeline written to `Documents/startup-timeline.log` of the app container, so
/// the "black second after Face ID" can be split into its phases from device data (pull it with
/// `devicectl device copy from --domain-type appDataContainer --source Documents/startup-timeline.log`).
///
/// One line per event: `t=<ms since process start> b=<ms since block start> <event> key=value ...`. One block per cold
/// launch (`=== launch`) and per return to the foreground (`--- foreground`). All times are `CACurrentMediaTime()`
/// (the `mach_absolute_time` base, the same as `CADisplayLink.timestamp`), so the display link ticks line up with the
/// events. Only event names and numbers: no account data, no ids, no hosts.
///
/// Every `PassYPerf.mark` arrives here. App and scene lifecycle come from notifications (with a state snapshot:
/// application / scene state, protected data, thermal state, low power, screen fps and the window list incl. alpha
/// and background color). Some events open a watch window (`watch(_:)`, 3 s): a `CADisplayLink` logs the first tick
/// after each event and every frame gap > 25 ms, and a background watchdog logs main-thread hangs > 50 ms (with the
/// time they began). Observer effect: a running display link keeps the display pipeline awake, like a screen
/// recording. Writing `events` into `Documents/startup-timeline-mode` turns both monitors off (events only).
public enum PassYStartupTimeline {
    // MARK: Constants

    /// The length of a watch window (seconds).
    static let watchSeconds: CFTimeInterval = 3

    /// The frame gap that is logged (seconds).
    static let gapThreshold: CFTimeInterval = 0.025

    /// The main-thread hang that is logged (seconds).
    static let hangThreshold: CFTimeInterval = 0.05

    // MARK: State (guarded by `lock`)

    private static let lock = NSLock()
    private static let writeQueue = DispatchQueue(label: "de.aiity.passy.timeline", qos: .utility)
    nonisolated(unsafe) private static var isStarted = false
    nonisolated(unsafe) private static var fileDescriptor: Int32 = -1
    nonisolated(unsafe) private static var unwritten: [String] = []
    nonisolated(unsafe) private static var processStart: CFTimeInterval = 0
    nonisolated(unsafe) private static var blockStart: CFTimeInterval = 0
    nonisolated(unsafe) private static var foregroundCount = 0
    nonisolated(unsafe) private static var pendingTicks: [(name: String, time: CFTimeInterval)] = []
    nonisolated(unsafe) private static var watchStart: CFTimeInterval = 0
    nonisolated(unsafe) private static var watchUntil: CFTimeInterval = 0
    nonisolated(unsafe) private static var monitorsEnabled = true
    /// Whether the scene is in the foreground (main thread; a new block starts with the next foreground).
    @MainActor private static var isInForeground = false
    /// The app (main thread).
    @MainActor private static var application: UIApplication?

    // MARK: Start

    /// Starts the timeline (once per process): opens the log, writes the launch block and observes the lifecycle.
    /// Call it first thing in `application(_:didFinishLaunchingWithOptions:)` (BitwardenKit is extension safe, so the
    /// app hands in its `UIApplication`).
    @MainActor
    public static func start(application: UIApplication) {
        self.application = application
        let now = CACurrentMediaTime()
        lock.lock()
        guard !isStarted else { lock.unlock(); return }
        isStarted = true
        processStart = now - processAge()
        blockStart = now
        monitorsEnabled = readMode() != "events"
        lock.unlock()

        let prewarm = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
        write(String(
            format: "=== launch pid=%d wall=%.3f mono=%.3f processAgeMs=%.1f prewarm=%d mode=%@",
            getpid(), Date().timeIntervalSince1970, now, (now - processStart) * 1000, prewarm ? 1 : 0,
            monitorsEnabled ? "full" : "events",
        ), at: now, raw: true)
        event("didFinishLaunching", snapshot: true, watch: true)
        observeLifecycle()
        if monitorsEnabled { Watchdog.shared.start() }
    }

    // MARK: Events

    /// Logs an event (any thread). `snapshot` adds the state and the window list (main thread only), `watch` opens a
    /// watch window. Every event waits for the first display link tick after it while a watch window runs.
    public static func event(_ name: String, _ fields: String = "", snapshot: Bool = false, watch: Bool = false) {
        let now = CACurrentMediaTime()
        lock.lock()
        let started = isStarted
        lock.unlock()
        guard started else { return }

        var line = name
        if !fields.isEmpty { line += " " + fields }
        if !Thread.isMainThread { line += " thread=bg" }
        write(line, at: now)

        if Thread.isMainThread {
            MainActor.assumeIsolated {
                if snapshot { write("  state " + stateDescription(), at: now) }
                if snapshot { for window in windowDescriptions() { write("  window " + window, at: now) } }
                if watch { self.watch(name, at: now) }
                lock.lock()
                let watching = watchUntil > now
                if watching { pendingTicks.append((name, now)) }
                lock.unlock()
            }
        } else {
            lock.lock()
            if watchUntil > now { pendingTicks.append((name, now)) }
            lock.unlock()
        }
    }

    /// Opens (or extends) a watch window: display link gap monitor and main-thread watchdog for `watchSeconds`.
    @MainActor
    static func watch(_ reason: String, at now: CFTimeInterval) {
        lock.lock()
        let enabled = monitorsEnabled
        if watchUntil <= now { watchStart = now }
        watchUntil = max(watchUntil, now + watchSeconds)
        lock.unlock()
        guard enabled else { return }
        FrameMonitor.shared.run(reason: reason)
    }

    /// Whether a watch window runs (any thread).
    static func isWatching(_ time: CFTimeInterval) -> (Bool, windowStart: CFTimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        return (watchUntil > time, watchStart)
    }

    /// Takes the events waiting for a display link tick.
    static func takePendingTicks() -> [(name: String, time: CFTimeInterval)] {
        lock.lock()
        defer { lock.unlock() }
        let ticks = pendingTicks
        pendingTicks = []
        return ticks
    }

    // MARK: Writing

    /// Appends one line (`raw` lines carry no time prefix). The time is taken by the caller; the write runs on a
    /// serial background queue (`write(2)` per line, no buffering in the process, so a kill loses at most the queue).
    static func write(_ text: String, at time: CFTimeInterval, raw: Bool = false) {
        lock.lock()
        let line: String
        if raw {
            line = text + "\n"
        } else {
            line = String(format: "t=%9.1f b=%8.1f ", (time - processStart) * 1000, (time - blockStart) * 1000)
                + text + "\n"
        }
        lock.unlock()
        writeQueue.async {
            if fileDescriptor < 0 { openFile() }
            guard fileDescriptor >= 0 else {
                // Protected data not available yet (device locked): keep the lines until the file opens.
                if unwritten.count < 2000 { unwritten.append(line) }
                return
            }
            if !unwritten.isEmpty {
                let lines = unwritten
                unwritten = []
                lines.forEach(writeLine)
            }
            writeLine(line)
        }
    }

    /// Writes one line to the open file (write queue).
    private static func writeLine(_ line: String) {
        var data = Array(line.utf8)
        _ = data.withUnsafeMutableBytes { Darwin.write(fileDescriptor, $0.baseAddress, $0.count) }
    }

    /// Opens the log for appending (write queue). Keeps one older log once it grows beyond 4 MB.
    private static func openFile() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let url = documents.appendingPathComponent("startup-timeline.log")
        if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, size > 4_000_000 {
            let old = documents.appendingPathComponent("startup-timeline.old.log")
            try? FileManager.default.removeItem(at: old)
            try? FileManager.default.moveItem(at: url, to: old)
        }
        fileDescriptor = open(url.path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    }

    /// The monitor mode written to `Documents/startup-timeline-mode` (`full` by default, `events`).
    private static func readMode() -> String {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let text = try? String(contentsOf: documents.appendingPathComponent("startup-timeline-mode"),
                                     encoding: .utf8)
        else { return "full" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The seconds since the process started (sysctl `kinfo_proc.p_starttime`, wall clock).
    private static func processAge() -> CFTimeInterval {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return 0 }
        let start = info.kp_proc.p_un.__p_starttime
        let startSeconds = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        return max(0, Date().timeIntervalSince1970 - startSeconds)
    }

    // MARK: Lifecycle

    /// Observes the app and scene lifecycle notifications (each with a state snapshot).
    @MainActor
    private static func observeLifecycle() {
        let center = NotificationCenter.default
        let events: [(Notification.Name, String, Bool)] = [
            (UIApplication.willEnterForegroundNotification, "app.willEnterForeground", true),
            (UIApplication.didBecomeActiveNotification, "app.didBecomeActive", true),
            (UIApplication.willResignActiveNotification, "app.willResignActive", false),
            (UIApplication.didEnterBackgroundNotification, "app.didEnterBackground", false),
            (UIApplication.protectedDataDidBecomeAvailableNotification, "app.protectedDataAvailable", false),
            (UIApplication.protectedDataWillBecomeUnavailableNotification, "app.protectedDataUnavailable", false),
            (UIScene.willConnectNotification, "scene.willConnect", true),
            (UIScene.willEnterForegroundNotification, "scene.willEnterForeground", true),
            (UIScene.didActivateNotification, "scene.didActivate", true),
            (UIScene.willDeactivateNotification, "scene.willDeactivate", false),
            (UIScene.didEnterBackgroundNotification, "scene.didEnterBackground", false),
            (ProcessInfo.thermalStateDidChangeNotification, "thermalStateChanged", false),
            (Notification.Name.NSProcessInfoPowerStateDidChange, "powerStateChanged", false),
        ]
        for (name, label, watch) in events {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    if name == UIScene.willEnterForegroundNotification
                        || name == UIApplication.willEnterForegroundNotification { beginForegroundBlock() }
                    if name == UIScene.didEnterBackgroundNotification { isInForeground = false }
                    event(label, snapshot: true, watch: watch)
                }
            }
        }
    }

    /// Starts a new block for a return to the foreground (the launch block covers the first one).
    @MainActor
    private static func beginForegroundBlock() {
        let now = CACurrentMediaTime()
        guard !isInForeground else { return }
        isInForeground = true
        lock.lock()
        foregroundCount += 1
        let isLaunch = foregroundCount == 1
        if !isLaunch { blockStart = now }
        let count = foregroundCount
        lock.unlock()
        guard !isLaunch else { return }
        write(String(format: "--- foreground n=%d wall=%.3f mono=%.3f", count, Date().timeIntervalSince1970, now),
              at: now, raw: true)
    }

    // MARK: Snapshot

    /// Application and scene state, protected data, thermal state, power mode and display rates.
    @MainActor
    static func stateDescription() -> String {
        guard let app = application else { return "app=-" }
        let appState = switch app.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
        let scenes = app.connectedScenes.map { scene -> String in
            switch scene.activationState {
            case .foregroundActive: "fgActive"
            case .foregroundInactive: "fgInactive"
            case .background: "bg"
            case .unattached: "unattached"
            @unknown default: "unknown"
            }
        }.joined(separator: ",")
        let thermal = switch ProcessInfo.processInfo.thermalState {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
        let screen = app.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        let style = app.connectedScenes.compactMap { ($0 as? UIWindowScene)?.traitCollection.userInterfaceStyle }
            .first.map { $0 == .dark ? "dark" : "light" } ?? "-"
        return "app=\(appState) scenes=[\(scenes)] protectedData=\(app.isProtectedDataAvailable ? 1 : 0) "
            + "thermal=\(thermal) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0) "
            + "maxFps=\(screen?.maximumFramesPerSecond ?? 0) style=\(style)"
    }

    /// One line per window: class, level, key, hidden, alpha, resolved background color, root view controller class.
    @MainActor
    static func windowDescriptions() -> [String] {
        (application?.connectedScenes ?? []).compactMap { $0 as? UIWindowScene }.flatMap(\.windows).map { window in
            "\(type(of: window)) level=\(Int(window.windowLevel.rawValue)) key=\(window.isKeyWindow ? 1 : 0) "
                + "hidden=\(window.isHidden ? 1 : 0) alpha=\(String(format: "%.2f", window.alpha)) "
                + "bg=\(colorDescription(window.backgroundColor, traits: window.traitCollection)) "
                + "root=\(window.rootViewController.map { "\(type(of: $0))" } ?? "-") "
                + "rootBg=\(colorDescription(window.rootViewController?.view.backgroundColor, traits: window.traitCollection))"
        }
    }

    /// A color as `r,g,b,a` (0-255, alpha 0-1) resolved for the traits, `nil` for none.
    @MainActor
    private static func colorDescription(_ color: UIColor?, traits: UITraitCollection) -> String {
        guard let color else { return "nil" }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "%d,%d,%d,%.2f", Int(red * 255), Int(green * 255), Int(blue * 255), alpha)
    }
}

// MARK: - FrameMonitor

/// The display link of the watch windows: first tick after each event, gaps > 25 ms, a summary per window.
@MainActor
private final class FrameMonitor: NSObject {
    static let shared = FrameMonitor()

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var frames = 0
    private var maxGap: CFTimeInterval = 0
    private var gaps = 0
    private var reason = ""

    func run(reason: String) {
        guard link == nil else { return }
        self.reason = reason
        last = 0
        frames = 0
        maxGap = 0
        gaps = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // Default frame rate range on purpose: the monitor should not ask for a faster display than the app does.
        link.add(to: .main, forMode: .common)
        self.link = link
        PassYStartupTimeline.write("dl.start reason=\(reason)", at: CACurrentMediaTime())
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let timestamp = link.timestamp
        if frames == 0 {
            PassYStartupTimeline.write(String(
                format: "dl.first vsyncAgoMs=%.1f durationMs=%.2f intervalMs=%.2f range=%.0f-%.0f/%.0f",
                (now - timestamp) * 1000, link.duration * 1000, (link.targetTimestamp - timestamp) * 1000,
                link.preferredFrameRateRange.minimum, link.preferredFrameRateRange.maximum,
                link.preferredFrameRateRange.preferred ?? 0,
            ), at: now)
        }
        for pending in PassYStartupTimeline.takePendingTicks() {
            PassYStartupTimeline.write(String(format: "dl.tickAfter %@ +%.1fms", pending.name, (now - pending.time) * 1000),
                                       at: now)
        }
        if last > 0 {
            let gap = timestamp - last
            maxGap = max(maxGap, gap)
            if gap > PassYStartupTimeline.gapThreshold {
                gaps += 1
                PassYStartupTimeline.write(String(
                    format: "dl.gap ms=%.1f began=%.1f intervalMs=%.2f", gap * 1000,
                    PassYStartupTimeline.relative(last), (link.targetTimestamp - timestamp) * 1000,
                ), at: now)
            }
        }
        last = timestamp
        frames += 1
        if !PassYStartupTimeline.isWatching(now).0 {
            PassYStartupTimeline.write(String(
                format: "dl.end reason=%@ frames=%d gaps=%d maxGapMs=%.1f intervalMs=%.2f",
                reason, frames, gaps, maxGap * 1000, (link.targetTimestamp - timestamp) * 1000,
            ), at: now)
            link.invalidate()
            self.link = nil
        }
    }
}

extension PassYStartupTimeline {
    /// A media time as ms since process start (for `began=` fields).
    static func relative(_ time: CFTimeInterval) -> Double {
        lock.lock()
        defer { lock.unlock() }
        return (time - processStart) * 1000
    }
}

// MARK: - Watchdog

/// Pings the main thread every 16 ms during a watch window and logs hangs > 50 ms with the time they began.
private final class Watchdog: @unchecked Sendable {
    static let shared = Watchdog()

    private var thread: Thread?

    func start() {
        guard thread == nil else { return }
        let thread = Thread { [self] in loop() }
        thread.name = "de.aiity.passy.timeline.watchdog"
        thread.qualityOfService = .userInteractive
        thread.start()
        self.thread = thread
    }

    private func loop() {
        let semaphore = DispatchSemaphore(value: 0)
        while true {
            let begin = CACurrentMediaTime()
            let (watching, windowStart) = PassYStartupTimeline.isWatching(begin)
            guard watching else {
                usleep(50000)
                continue
            }
            DispatchQueue.main.async { semaphore.signal() }
            semaphore.wait()
            let end = CACurrentMediaTime()
            let hang = end - begin
            // A ping sent before a suspension returns after the resume: only pings from inside the window count.
            if hang > PassYStartupTimeline.hangThreshold, begin >= windowStart {
                PassYStartupTimeline.write(String(
                    format: "hang ms=%.1f began=%.1f", hang * 1000, PassYStartupTimeline.relative(begin),
                ), at: end)
            }
            usleep(16000)
        }
    }
}
#endif
