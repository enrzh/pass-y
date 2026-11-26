#if DEBUG
import QuartzCore
import UIKit

// MARK: - PassYNavigationProbe

/// DEBUG only: the navigation steps of `ViewLoggingNavigationController` as `PassYPerf` marks
/// (`startup mark=nav.<step> t=<seconds>`), so a UI test can split "back tap -> previous page shown", and the frames of a
/// push/pop transition (willShow -> didShow): the longest frame and the hitch time (time beyond the display's frame
/// interval), logged as `frameprobe frames=... maxGapMs=... hitchMs=...`. `nav.firstFrame` marks the first frame
/// after a transition started (push, pop, or a modal dismiss: `nav.dismiss` -> `nav.dismissed`).
@MainActor
public final class PassYNavigationProbe: NSObject {
    /// The one probe of the process (one transition at a time).
    public static let shared = PassYNavigationProbe()

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var frames = 0
    private var maxGap: CFTimeInterval = 0
    private var hitch: CFTimeInterval = 0

    /// Logs a navigation step (`nav.<step>`).
    public nonisolated static func mark(_ step: String) {
        PassYPerf.mark("nav.\(step)")
    }

    /// Starts counting the frames of a transition.
    public func startTransition() {
        link?.invalidate()
        frames = 0
        maxGap = 0
        hitch = 0
        last = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops counting and logs the `frameprobe` line (nothing if no transition was running).
    public func endTransition() {
        guard let link else { return }
        link.invalidate()
        self.link = nil
        PassYPerf.logger.notice(
            "frameprobe frames=\(self.frames, privacy: .public) maxGapMs=\(self.maxGap * 1000, format: .fixed(precision: 1), privacy: .public) hitchMs=\(self.hitch * 1000, format: .fixed(precision: 1), privacy: .public)",
        )
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { last = link.timestamp }
        // The first frame callback of the transition (the answer to "did the animation start right away").
        guard last > 0 else { return Self.mark("firstFrame") }
        frames += 1
        let gap = link.timestamp - last
        let interval = max(link.targetTimestamp - link.timestamp, 1.0 / 120)
        maxGap = max(maxGap, gap)
        if gap > interval * 1.5 { hitch += gap - interval }
    }
}
#endif
