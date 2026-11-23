#if DEBUG
import Darwin
import Foundation
import notify
import ObjectiveC
import UIKit

/// DEBUG only: explains what keeps the app from becoming idle for XCUITest ("App animations complete notification
/// not received").
///
/// XCUITest's animation idle check (`XCTAnimationsIdleNotifier` in XCTAutomationSupport, injected into the app) counts
/// `-[UIViewAnimationState animationDidStart:]` against `animationDidStop:finished:` and reports idle only when the
/// count is zero. A start without a stop (for example a UIKit animation on a layer that left the window tree but is
/// kept alive) blocks every later idle wait of the process, even when no layer on screen animates. So the dump lists:
/// - XCUITest's own verdict (`isAnimationInProgress`) and our mirror of its counter,
/// - every outstanding (started, not stopped) UIView animation with its layer, owner views and the stack that added it,
/// - every running Core Animation animation of all windows (internal windows such as the keyboard included),
/// - the first responder, and whether the main thread answers at all (written from a background queue).
///
/// Event driven (a Darwin notification, no timer). Trigger it while a test is stuck:
/// `xcrun simctl spawn <udid> notifyutil -p de.aiity.passy.dumpAnimations`. The result is written to the log
/// (`ANIMDUMP ...`) and appended to `<tmp>/passy-animations.txt` in the app's container.
/// `de.aiity.passy.plantStall` / `de.aiity.passy.unplantStall` start/stop a known endless UIView animation (positive
/// control of the dump and the chain's stall watcher).
enum PassYAnimationDump {
    static let notificationName = "de.aiity.passy.dumpAnimations"
    static let plantName = "de.aiity.passy.plantStall"
    static let unplantName = "de.aiity.passy.unplantStall"

    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var tokens: [Int32] = []
    private static let queue = DispatchQueue(label: "de.aiity.passy.animdump")
    private static let fileLock = NSLock()

    /// Gives the window scene to inspect (`UIApplication.shared` is unavailable in app extensions).
    nonisolated(unsafe) private static var sceneProvider: (() -> UIWindowScene?)?

    /// Starts listening for the notifications and tracking UIView animations (once).
    @MainActor
    static func installOnce(sceneProvider: @escaping () -> UIWindowScene?) {
        guard !installed else { return }
        Self.sceneProvider = sceneProvider
        installed = true
        PassYAnimationTracker.install()
        var token: Int32 = 0
        // Delivered on a background queue: the trigger line and the main-thread ping are written even if the main
        // thread is blocked (the dump itself needs the main thread).
        notify_register_dispatch(notificationName, &token, queue) { _ in PassYAnimationDump.trigger() }
        tokens.append(token)
        notify_register_dispatch(plantName, &token, queue) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { PassYAnimationDump.plantStall() } }
        }
        tokens.append(token)
        notify_register_dispatch(unplantName, &token, queue) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { PassYAnimationDump.unplantStall() } }
        }
        tokens.append(token)
    }

    /// Background side of a trigger: header line, then the main-thread dump, with a note if main does not answer.
    private static func trigger() {
        let requested = Date()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                PassYAnimationDump.dump(mainLatency: Date().timeIntervalSince(requested))
            }
            done.signal()
        }
        if done.wait(timeout: .now() + 5) == .timedOut {
            append("=== \(stamp(requested)) ANIMDUMP-MAIN-BLOCKED pid=\(getpid()): the main thread did not answer within 5 s\n")
            done.wait()
            append("=== \(stamp(Date())) main thread answered after \(ms(Date().timeIntervalSince(requested))) ms\n")
        }
    }

    // MARK: Report

    /// All windows, internal ones (keyboard, text effects) included.
    @MainActor
    private static func allWindows() -> [UIWindow] {
        var windows = sceneProvider?()?.windows ?? []
        let selector = NSSelectorFromString("allWindowsIncludingInternalWindows:onlyVisibleWindows:")
        if let method = class_getClassMethod(UIWindow.self, selector) {
            typealias Fn = @convention(c) (AnyClass, Selector, Bool, Bool) -> NSArray?
            let all = unsafeBitCast(method_getImplementation(method), to: Fn.self)(UIWindow.self, selector, true, false)
            for case let window as UIWindow in all ?? [] where !windows.contains(where: { $0 === window }) {
                windows.append(window)
            }
        }
        return windows
    }

    /// All running Core Animation animations: `windowIndex/path-of-layer [keys]` per layer.
    @MainActor
    static func report() -> [String] {
        var lines: [String] = []
        func visit(_ layer: CALayer, _ path: String) {
            let keys = layer.animationKeys() ?? []
            if !keys.isEmpty {
                let described = keys.compactMap { key -> String? in
                    guard let animation = layer.animation(forKey: key) else { return nil }
                    let repeating = animation.repeatCount >= .greatestFiniteMagnitude || animation.repeatDuration >= .greatestFiniteMagnitude
                    return "\(key)\(repeating ? " (repeats forever)" : "") \(type(of: animation)) duration=\(animation.duration)"
                        + " delegate=\(animation.delegate.map { "\(type(of: $0))" } ?? "-")"
                }
                lines.append("\(path) <\(type(of: layer))> hidden=\(layer.isHidden) opacity=\(layer.opacity) speed=\(layer.speed) \(described)\(owner(of: layer))")
            }
            for (index, sub) in (layer.sublayers ?? []).enumerated() {
                visit(sub, "\(path)/\(index)")
            }
        }
        for (index, window) in allWindows().enumerated() {
            lines.append("window w\(index)(\(type(of: window))) hidden=\(window.isHidden) alpha=\(window.alpha) level=\(window.windowLevel.rawValue) key=\(window.isKeyWindow) layerSpeed=\(window.layer.speed)")
            visit(window.layer, "w\(index)(\(type(of: window)))")
        }
        return lines
    }

    /// The view that owns the layer and its chain of superviews and the view controller (to name the screen).
    @MainActor
    static func owner(of layer: CALayer) -> String {
        var current: CALayer? = layer
        var view: UIView?
        while let candidate = current, view == nil {
            view = candidate.delegate as? UIView
            current = candidate.superlayer
        }
        guard var walker = view else { return " views=- (no owning view)" }
        var chain: [String] = []
        var controller: String?
        while true {
            chain.append("\(type(of: walker))" + (walker.accessibilityIdentifier.map { "#\($0)" } ?? ""))
            if controller == nil, let vc = walker.next as? UIViewController { controller = "\(type(of: vc))" }
            guard let next = walker.superview else { break }
            walker = next
        }
        return " views=\(chain.prefix(14).joined(separator: " < "))\(chain.count > 14 ? " < ...(\(chain.count))" : "") vc=\(controller ?? "-")"
    }

    /// XCUITest's own animation idle verdict (nil when XCTAutomationSupport is not loaded).
    private static func xctAnimationInProgress() -> Bool? {
        guard let cls = NSClassFromString("XCTAnimationsIdleNotifier") else { return nil }
        let selector = NSSelectorFromString("isAnimationInProgress")
        guard let method = class_getClassMethod(cls, selector) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector) -> Bool
        return unsafeBitCast(method_getImplementation(method), to: Fn.self)(cls, selector)
    }

    @MainActor
    private static func firstResponder() -> String {
        func find(_ view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for sub in view.subviews { if let hit = find(sub) { return hit } }
            return nil
        }
        for window in allWindows() {
            if let hit = find(window) { return "\(type(of: hit))\(hit.accessibilityIdentifier.map { "#\($0)" } ?? "") in \(type(of: window))" }
        }
        return "-"
    }

    @MainActor
    static func dump(mainLatency: TimeInterval = 0) {
        let lines = report()
        let animated = lines.filter { !$0.hasPrefix("window ") }
        let xct = xctAnimationInProgress().map { "\($0)" } ?? "n/a (XCTAutomationSupport not loaded)"
        var text = [
            "pid=\(getpid()) uptime=\(Int(ProcessInfo.processInfo.systemUptime)) mainLatency=\(ms(mainLatency)) ms",
            "XCTAnimationsIdleNotifier.isAnimationInProgress=\(xct)",
            "firstResponder=\(firstResponder()) appState=\(sceneProvider?()?.activationState.rawValue ?? -1)",
        ]
        text += PassYAnimationTracker.report()
        text.append("-- running Core Animation animations: \(animated.count)")
        text += lines
        NSLog("ANIMDUMP %d\n%@", animated.count, text.joined(separator: "\n"))
        append("=== \(stamp(Date())) ANIMDUMP \(animated.count)\n" + text.joined(separator: "\n") + "\n")
    }

    // MARK: Positive control

    @MainActor
    private static func plantStall() {
        guard let window = sceneProvider?()?.windows.first else { return }
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        view.accessibilityIdentifier = "PassYPlantedStall"
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        window.addSubview(view)
        UIView.animate(withDuration: 0.8, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            view.alpha = 0.5
        }
        append("=== \(stamp(Date())) PLANTED endless UIView animation on PassYPlantedStall\n")
    }

    @MainActor
    private static func unplantStall() {
        for window in sceneProvider?()?.windows ?? [] {
            for view in window.subviews where view.accessibilityIdentifier == "PassYPlantedStall" {
                view.layer.removeAllAnimations()
                view.removeFromSuperview()
            }
        }
        append("=== \(stamp(Date())) UNPLANTED\n")
    }

    // MARK: Output

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private static func ms(_ seconds: TimeInterval) -> Int { Int((seconds * 1000).rounded()) }

    /// Appends a block (one per trigger), so several stalls of one run stay readable.
    static func append(_ block: String) {
        fileLock.lock()
        defer { fileLock.unlock() }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("passy-animations.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(block.utf8))
            try? handle.close()
        } else {
            try? block.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// DEBUG only: mirrors XCUITest's animation counter. Every CAAnimation whose delegate is a `UIViewAnimationState`
/// gets a token when it is added to a layer (with the layer, key and the adding call stack); `animationDidStart:` /
/// `animationDidStop:finished:` of `UIViewAnimationState` mark it started/stopped. Started but never stopped entries
/// are what keeps XCUITest's "animations complete" from arriving.
final class PassYAnimationTracker {
    private final class Entry {
        let token: Int
        let key: String
        let animation: String
        weak var layer: CALayer?
        let layerType: String
        let added: Date
        var started: Date?
        let stack: [NSNumber]

        init(token: Int, key: String, animation: String, layer: CALayer, added: Date, stack: [NSNumber]) {
            self.token = token
            self.key = key
            self.animation = animation
            self.layer = layer
            layerType = "\(type(of: layer))"
            self.added = added
            self.stack = stack
        }
    }

    private static let tokenKey = "passyAnimToken"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var entries: [Int: Entry] = [:]
    nonisolated(unsafe) private static var nextToken = 1
    nonisolated(unsafe) private static var starts = 0
    nonisolated(unsafe) private static var stops = 0
    nonisolated(unsafe) private static var untrackedStarts: [String] = []
    nonisolated(unsafe) private static var droppedNeverStarted = 0
    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var stateClass: AnyClass?

    static func install() {
        guard !installed, let state = NSClassFromString("UIViewAnimationState") else { return }
        installed = true
        stateClass = state
        swizzleAdd()
        swizzleStart(state)
        swizzleStop(state)
    }

    private static func swizzleAdd() {
        let selector = #selector(CALayer.add(_:forKey:))
        guard let method = class_getInstanceMethod(CALayer.self, selector) else { return }
        typealias Fn = @convention(c) (CALayer, Selector, CAAnimation, NSString?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        let block: @convention(block) (CALayer, CAAnimation, NSString?) -> Void = { layer, animation, key in
            if let delegate = animation.delegate as? NSObject, let state = PassYAnimationTracker.stateClass,
               delegate.isKind(of: state) {
                PassYAnimationTracker.noteAdd(layer: layer, animation: animation, key: key as String?)
            }
            original(layer, selector, animation, key)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleStart(_ state: AnyClass) {
        let selector = NSSelectorFromString("animationDidStart:")
        guard let method = class_getInstanceMethod(state, selector) else { return }
        typealias Fn = @convention(c) (AnyObject, Selector, CAAnimation?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        let block: @convention(block) (AnyObject, CAAnimation?) -> Void = { object, animation in
            PassYAnimationTracker.noteStart(animation)
            original(object, selector, animation)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func swizzleStop(_ state: AnyClass) {
        let selector = NSSelectorFromString("animationDidStop:finished:")
        guard let method = class_getInstanceMethod(state, selector) else { return }
        typealias Fn = @convention(c) (AnyObject, Selector, CAAnimation?, Bool) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
        let block: @convention(block) (AnyObject, CAAnimation?, Bool) -> Void = { object, animation, finished in
            PassYAnimationTracker.noteStop(animation)
            original(object, selector, animation, finished)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private static func describe(_ animation: CAAnimation) -> String {
        let keyPath = (animation as? CAPropertyAnimation)?.keyPath ?? "-"
        let repeating = animation.repeatCount >= .greatestFiniteMagnitude || animation.repeatDuration >= .greatestFiniteMagnitude
        return "\(type(of: animation)) keyPath=\(keyPath) duration=\(animation.duration)\(repeating ? " REPEATS-FOREVER" : "")"
    }

    private static func noteAdd(layer: CALayer, animation: CAAnimation, key: String?) {
        let stack = Thread.callStackReturnAddresses
        lock.lock()
        defer { lock.unlock() }
        let token = nextToken
        nextToken += 1
        // The layer stores a copy; KVC values are copied with it, so start/stop can find the entry.
        animation.setValue(token, forKey: tokenKey)
        entries[token] = Entry(token: token, key: key ?? "-", animation: describe(animation), layer: layer,
                               added: Date(), stack: Array(stack.prefix(48)))
        if entries.count > 400 {
            let cutoff = Date().addingTimeInterval(-120)
            for (token, entry) in entries where entry.started == nil && entry.added < cutoff {
                entries[token] = nil
                droppedNeverStarted += 1
            }
        }
    }

    private static func noteStart(_ animation: CAAnimation?) {
        lock.lock()
        defer { lock.unlock() }
        starts += 1
        if let token = animation?.value(forKey: tokenKey) as? Int, let entry = entries[token] {
            entry.started = Date()
        } else if untrackedStarts.count < 20 {
            untrackedStarts.append(animation.map(describe) ?? "nil animation")
        }
    }

    private static func noteStop(_ animation: CAAnimation?) {
        lock.lock()
        defer { lock.unlock() }
        stops += 1
        if let token = animation?.value(forKey: tokenKey) as? Int {
            entries[token] = nil
        }
    }

    /// Symbolized frames (image and symbol), the tracker's own frames skipped.
    private static func symbolize(_ stack: [NSNumber]) -> [String] {
        stack.dropFirst(2).prefix(30).map { address in
            var info = Dl_info()
            let pointer = UnsafeRawPointer(bitPattern: address.uintValue)
            guard let pointer, dladdr(pointer, &info) != 0 else { return String(format: "0x%lx", address.uintValue) }
            let image = info.dli_fname.map { (String(cString: $0) as NSString).lastPathComponent } ?? "?"
            let symbol = info.dli_sname.map { String(cString: $0) } ?? "?"
            let offset = info.dli_saddr.map { Int(bitPattern: pointer) - Int(bitPattern: $0) } ?? 0
            return "\(image) \(symbol) + \(offset)"
        }
    }

    @MainActor
    static func report() -> [String] {
        lock.lock()
        let snapshot = Array(entries.values)
        let counts = (starts, stops, droppedNeverStarted, untrackedStarts)
        lock.unlock()
        let now = Date()
        let outstanding = snapshot.filter { $0.started != nil }.sorted { $0.added < $1.added }
        var lines = [
            "-- UIViewAnimationState starts=\(counts.0) stops=\(counts.1) (XCUITest counter mirror \(counts.0 - counts.1))"
                + " outstanding tracked=\(outstanding.count) addedNotStarted=\(snapshot.count - outstanding.count)"
                + " droppedNeverStarted=\(counts.2)",
        ]
        if !counts.3.isEmpty { lines.append("untracked starts (first 20): " + counts.3.joined(separator: " | ")) }
        for entry in outstanding {
            let age = Int(now.timeIntervalSince(entry.started ?? entry.added))
            var line = "OUTSTANDING #\(entry.token) age=\(age)s key=\(entry.key) \(entry.animation) layer=\(entry.layerType)"
            if let layer = entry.layer {
                var root: CALayer = layer
                while let superlayer = root.superlayer { root = superlayer }
                let inWindow = root.delegate is UIWindow || NSStringFromClass(type(of: root)) == "UIWindowLayer"
                line += " alive inWindow=\(inWindow) root=\(type(of: root))/\(root.delegate.map { "\(type(of: $0))" } ?? "-")"
                line += " stillAttached=\(layer.animation(forKey: entry.key) != nil) speed=\(layer.speed) hidden=\(layer.isHidden)"
                line += PassYAnimationDump.owner(of: layer)
            } else {
                line += " layer DEALLOCATED"
            }
            lines.append(line)
            lines += symbolize(entry.stack).map { "    " + $0 }
        }
        return lines
    }
}
#endif
