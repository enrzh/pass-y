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

    /// Starts listening for the notification (once).
    @MainActor
    static func installOnce() {
        guard !installed else { return }
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
                lines.append("\(path) <\(type(of: layer))> hidden=\(layer.isHidden) opacity=\(layer.opacity) \(described)")
            }
            for (index, sub) in (layer.sublayers ?? []).enumerated() {
                visit(sub, "\(path)/\(index)")
            }
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for (index, window) in scene.windows.enumerated() {
                visit(window.layer, "w\(index)(\(type(of: window)))")
            }
        }
        return lines
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
