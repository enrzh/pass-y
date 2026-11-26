import BitwardenKit
import Observation
import SwiftUI

// MARK: - PassYCountdown

/// The countdown of a time-based code at one moment: seconds left, the fraction of the period left and the tone
/// (normal, then orange in the last 5 seconds, red in the last 2).
struct PassYCountdown: Equatable {
    // MARK: Types

    /// The colour step of a countdown.
    enum Tone: Equatable {
        /// More than 5 seconds left.
        case normal

        /// 5 to 3 seconds left (orange).
        case warning

        /// 2 seconds or less left (red).
        case critical

        /// The colour of the tone.
        var color: Color {
            switch self {
            case .normal: .accentColor
            case .warning: .orange
            case .critical: .red
            }
        }
    }

    // MARK: Properties

    /// The last seconds shown in orange.
    static let warningSeconds = 5

    /// The last seconds shown in red.
    static let criticalSeconds = 2

    /// The period of the code in seconds (at least 1).
    let period: Int

    /// The moment.
    let date: Date

    // MARK: Initialization

    /// Creates the countdown of a code with `period` at `date`.
    init(period: Int, date: Date) {
        self.period = max(period, 1)
        self.date = date
    }

    // MARK: Computed Properties

    /// The whole seconds left (rounded up: a code with any time left shows at least 1).
    var secondsRemaining: Int {
        min(max(TOTPExpirationCalculator.remainingSeconds(for: date, using: period), 0), period)
    }

    /// The fraction of the period left, 0 to 1.
    var fractionRemaining: Double {
        let left = TOTPExpirationCalculator.timeRemaining(for: date, using: TimeInterval(period)) / TimeInterval(period)
        return min(max(left, 0), 1)
    }

    /// The colour step.
    var tone: Tone {
        Self.tone(secondsRemaining: secondsRemaining)
    }

    /// The colour step for the seconds left.
    static func tone(secondsRemaining: Int) -> Tone {
        if secondsRemaining <= criticalSeconds { return .critical }
        if secondsRemaining <= warningSeconds { return .warning }
        return .normal
    }
}

// MARK: - PassYCountdownClock

/// One clock for every countdown of a page: it ticks once per second (on the second, also while scrolling) and the
/// rings read it, so a page of codes has one timer, not one per row. Only the ring views observe `now`; the rows
/// around them are not invalidated by a tick. Install it with `passYCountdownClock(timeProvider:)`.
@MainActor
@Observable
final class PassYCountdownClock {
    // MARK: Properties

    /// The current time, updated once per second.
    private(set) var now: Date

    /// Where the time comes from (a mock in tests).
    @ObservationIgnored private let timeProvider: any TimeProvider

    /// The running timer.
    @ObservationIgnored private var timer: Timer?

    // MARK: Initialization

    /// Creates a stopped clock.
    init(timeProvider: any TimeProvider) {
        self.timeProvider = timeProvider
        now = timeProvider.presentTime
    }

    // MARK: Methods

    /// Starts ticking on the next whole second.
    func start() {
        guard timer == nil else { return }
        now = timeProvider.presentTime
        let next = Date(timeIntervalSince1970: (Date().timeIntervalSince1970).rounded(.down) + 1)
        let timer = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops ticking.
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Reads the time again (called by the timer; tests call it directly).
    func tick() {
        now = timeProvider.presentTime
    }
}

extension EnvironmentValues {
    /// The countdown clock of the page, `nil` outside a `passYCountdownClock` page.
    @Entry var passYCountdownClock: PassYCountdownClock?
}

extension View {
    /// Gives the page one countdown clock for its `PassYCountdownRing`s; it runs while the page is on screen.
    ///
    /// - Parameters:
    ///   - timeProvider: Where the time comes from.
    ///   - isActive: Whether the page shows countdowns at all (no timer otherwise).
    ///
    func passYCountdownClock(timeProvider: any TimeProvider, isActive: Bool = true) -> some View {
        modifier(PassYCountdownClockModifier(timeProvider: timeProvider, isActive: isActive))
    }
}

/// Owns the clock of `passYCountdownClock`.
private struct PassYCountdownClockModifier: ViewModifier {
    let timeProvider: any TimeProvider
    let isActive: Bool

    @SwiftUI.State private var clock: PassYCountdownClock?

    func body(content: Content) -> some View {
        content
            .environment(\.passYCountdownClock, clock)
            .onAppear { update() }
            .onChange(of: isActive) { _, _ in update() }
            .onDisappear { clock?.stop() }
    }

    private func update() {
        guard isActive else {
            clock?.stop()
            return
        }
        if clock == nil { clock = PassYCountdownClock(timeProvider: timeProvider) }
        clock?.start()
    }
}

// MARK: - PassYCountdownRing

/// A small circular countdown: a ring that empties over the period with the seconds left inside, tinted by
/// `PassYCountdown.Tone`. It reads the page clock (`passYCountdownClock`); without one it shows the moment given.
/// Hidden from VoiceOver: the row's label reads the seconds left.
struct PassYCountdownRing: View {
    // MARK: Properties

    /// The period of the code in seconds.
    let period: Int

    /// The time used without a page clock (previews, tests).
    var fallbackDate = Date()

    /// The side length before Dynamic Type scaling.
    var size: CGFloat = 30

    @Environment(\.passYCountdownClock) private var clock

    /// The page's code options (Customize: ring and seconds can be switched off).
    @Environment(\.passYCodeOptions) private var options

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    // MARK: View

    var body: some View {
        let countdown = PassYCountdown(period: period, date: clock?.now ?? fallbackDate)
        let side = PassYDesign.IconSize.scaled(size, by: scale)
        let color = countdown.tone.color
        ZStack {
            if options.showsRing {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: countdown.fractionRemaining)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // One tick per second, swept linearly: a smooth ring from a 1 Hz clock.
                    .animation(
                        countdown.secondsRemaining == period ? .snappy : .linear(duration: 1),
                        value: countdown.date,
                    )
            }
            if options.showsSeconds {
                secondsText(countdown, color: color)
            }
        }
        .frame(width: side, height: side)
        .animation(.easeInOut(duration: 0.3), value: countdown.tone)
        .accessibilityHidden(true)
        .accessibilityIdentifier("CountdownRing")
    }

    /// The seconds left inside the ring.
    private func secondsText(_ countdown: PassYCountdown, color: Color) -> some View {
        Text("\(countdown.secondsRemaining)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(countdown.tone == .normal ? AnyShapeStyle(.secondary) : AnyShapeStyle(color))
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText(countsDown: true))
            .animation(.default, value: countdown.secondsRemaining)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Countdown rings") {
    HStack(spacing: 16) {
        PassYCountdownRing(period: 30, fallbackDate: Date(timeIntervalSinceReferenceDate: 30_000 + 1))
        PassYCountdownRing(period: 30, fallbackDate: Date(timeIntervalSinceReferenceDate: 30_000 + 15))
        PassYCountdownRing(period: 30, fallbackDate: Date(timeIntervalSinceReferenceDate: 30_000 + 26))
        PassYCountdownRing(period: 30, fallbackDate: Date(timeIntervalSinceReferenceDate: 30_000 + 29))
    }
    .padding()
}
#endif
