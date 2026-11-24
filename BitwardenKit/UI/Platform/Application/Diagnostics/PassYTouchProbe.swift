#if DEBUG
import QuartzCore
import UIKit

// MARK: - PassYTouchProbe

/// DEBUG only: touch-down and touch-up of the app window as `PassYPerf` marks, so a UI test can split
/// "button pressed -> action -> first transition frame" (button response work, ui-r10).
///
/// Logged per touch phase: `touchprobe phase=down|up t=<absolute seconds of the HID event> queueMs=<delivery delay>
/// view=<hit view class> id=<nearest accessibility identifier>`. `t` is the event's own timestamp (uptime) converted
/// to the absolute clock of the `startup mark=` lines; `queueMs` is how long the event waited before the main thread
/// delivered it (a busy main thread shows up here, not in a "now" mark).
public enum PassYTouchProbe {
    /// Records the touch phases of a window event (called from `ShakeWindow.sendEvent` before UIKit delivers it).
    @MainActor
    public static func record(_ event: UIEvent) {
        guard event.type == .touches, let touches = event.allTouches, touches.count == 1, let touch = touches.first
        else { return }
        let phase: String
        switch touch.phase {
        case .began: phase = "down"
        case .ended: phase = "up"
        case .cancelled: phase = "cancelled"
        default: return
        }
        let now = CFAbsoluteTimeGetCurrent()
        let queue = max(0, ProcessInfo.processInfo.systemUptime - touch.timestamp)
        let hidTime = now - queue
        let view = touch.view.map { String(describing: type(of: $0)) } ?? "-"
        let identifier = nearestIdentifier(touch.view)
        PassYPerf.logger.notice(
            "touchprobe phase=\(phase, privacy: .public) t=\(hidTime, format: .fixed(precision: 3), privacy: .public) queueMs=\(queue * 1000, format: .fixed(precision: 1), privacy: .public) view=\(view, privacy: .public) id=\(identifier, privacy: .public)",
        )
    }

    /// The accessibility identifier of the view or its nearest ancestor (`-` if none).
    private static func nearestIdentifier(_ view: UIView?) -> String {
        var current = view
        while let candidate = current {
            if let identifier = candidate.accessibilityIdentifier, !identifier.isEmpty { return identifier }
            current = candidate.superview
        }
        return "-"
    }
}
#endif
