import SwiftUI

// MARK: - PassYCodeExpiry

/// The countdown of a one-time code inside a detail row: a `PassYCountdownRing` on the page clock
/// (`passYCountdownClock`, one 1 Hz timer per page, no own animation loop) that reports once when the code's period
/// has passed so the page can generate the next code.
///
/// ```swift
/// PassYCodeExpiry(period: 30, generatedAt: model.codeGenerationDate) { refresh() }
/// ```
///
struct PassYCodeExpiry: View {
    /// The code period in seconds.
    let period: Int

    /// When the code was generated.
    let generatedAt: Date

    /// Called when the period of the code has passed.
    let onExpired: () -> Void

    @Environment(\.passYCountdownClock) private var clock

    var body: some View {
        let expired = clock.map { Self.isExpired(generatedAt: generatedAt, now: $0.now, period: period) } ?? false
        PassYCountdownRing(period: period, fallbackDate: generatedAt)
            .onChange(of: expired, initial: true) { _, isExpired in
                if isExpired { onExpired() }
            }
    }

    /// Whether `now` is in a later period than `generatedAt` (codes change at multiples of the period).
    static func isExpired(generatedAt: Date, now: Date, period: Int) -> Bool {
        let period = Double(max(period, 1))
        return (now.timeIntervalSince1970 / period).rounded(.down)
            > (generatedAt.timeIntervalSince1970 / period).rounded(.down)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Code expiry") {
    PassYCodeExpiry(period: 30, generatedAt: Date()) {}
        .padding()
}
#endif
