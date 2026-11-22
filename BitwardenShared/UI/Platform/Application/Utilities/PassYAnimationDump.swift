#if DEBUG
import Foundation
import UIKit

/// DEBUG only: lists every running Core Animation animation of all windows. Used to find what keeps the app from
/// becoming idle for XCUITest ("App animations complete notification not received").
///
/// Event driven (a Darwin notification, no timer). Trigger it while a test is stuck:
/// `xcrun simctl spawn <udid> notifyutil -p de.aiity.passy.dumpAnimations`. The result is written to the log
/// (`ANIMDUMP ...`) and to `<tmp>/passy-animations.txt` in the app's container.
enum PassYAnimationDump {
    static let notificationName = "de.aiity.passy.dumpAnimations"

    nonisolated(unsafe) private static var installed = false

    /// Gives the window scene to inspect (`UIApplication.shared` is unavailable in app extensions).
    nonisolated(unsafe) private static var sceneProvider: (() -> UIWindowScene?)?

    /// Starts listening for the notification (once).
    @MainActor
    static func installOnce(sceneProvider: @escaping () -> UIWindowScene?) {
        guard !installed else { return }
        Self.sceneProvider = sceneProvider
        installed = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { PassYAnimationDump.dump() } }
        }, notificationName as CFString, nil, .deliverImmediately)
    }

    /// All running animations: `windowIndex/path-of-layer [keys]` per layer.
    @MainActor
    static func report() -> [String] {
        var lines: [String] = []
        func visit(_ layer: CALayer, _ path: String) {
            let keys = layer.animationKeys() ?? []
            if !keys.isEmpty {
                let described = keys.compactMap { key -> String? in
                    guard let animation = layer.animation(forKey: key) else { return nil }
                    let repeating = animation.repeatCount == .infinity || animation.repeatDuration == .infinity
                    return "\(key)\(repeating ? " (repeats forever)" : "") \(type(of: animation))"
                }
                lines.append("\(path) <\(type(of: layer))> hidden=\(layer.isHidden) opacity=\(layer.opacity) \(described)\(owner(of: layer))")
            }
            for (index, sub) in (layer.sublayers ?? []).enumerated() {
                visit(sub, "\(path)/\(index)")
            }
        }
        for scene in [sceneProvider?()].compactMap({ $0 }) {
            for (index, window) in scene.windows.enumerated() {
                visit(window.layer, "w\(index)(\(type(of: window)))")
            }
        }
        return lines
    }

    /// The view that owns the layer and its chain of superviews and the view controller (to name the screen).
    @MainActor
    private static func owner(of layer: CALayer) -> String {
        var current: CALayer? = layer
        var view: UIView?
        while let candidate = current, view == nil {
            view = candidate.delegate as? UIView
            current = candidate.superlayer
        }
        guard var walker = view else { return "" }
        var chain: [String] = []
        var controller: String?
        while true {
            chain.append("\(type(of: walker))" + (walker.accessibilityIdentifier.map { "#\($0)" } ?? ""))
            if controller == nil, let vc = walker.next as? UIViewController { controller = "\(type(of: vc))" }
            guard let next = walker.superview else { break }
            walker = next
        }
        return " views=\(chain.prefix(14).joined(separator: " < ")) vc=\(controller ?? "-")"
    }

    @MainActor
    static func dump() {
        let lines = report()
        let text = lines.isEmpty ? "no running animations" : lines.joined(separator: "\n")
        NSLog("ANIMDUMP %d\n%@", lines.count, text)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("passy-animations.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
#endif
