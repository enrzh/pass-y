import SwiftUI

// MARK: - PassYSharedCountdown

/// One countdown ring for a whole page of codes (the verification codes page) instead of one per row. While the large
/// title is shown the ring sits at the trailing end of the title block; once the title has collapsed into the bar it
/// moves to the trailing end of the navigation bar (the two cross-fade). The rows of the page whose period is the
/// shared one show no ring of their own (`passYSharedCountdownPeriod`, read by `PassYCodeRow`).
///
/// The page title and the item count subtitle stay the system's (`navigationTitle`, `navigationSubtitle`), so the title
/// block has the same layout as on every other list page from the first frame.
///
/// ```swift
/// List { ... }
///     .passYSharedCountdown(period: 30, subtitle: "42 Items")
/// ```
///
enum PassYSharedCountdown {
    /// The period most codes of the page use (30 s when there are none yet or as the tie-breaker).
    ///
    /// - Parameter periods: The periods of the page's codes.
    /// - Returns: The most frequent period.
    ///
    static func dominantPeriod(_ periods: [Int]) -> Int {
        guard !periods.isEmpty else { return defaultPeriod }
        var counts = [Int: Int]()
        for period in periods {
            counts[period, default: 0] += 1
        }
        let best = counts.values.max() ?? 0
        let candidates = counts.filter { $0.value == best }.map(\.key)
        return candidates.contains(defaultPeriod) ? defaultPeriod : (candidates.min() ?? defaultPeriod)
    }

    /// The period of almost all codes.
    static let defaultPeriod = 30

    /// How far the list must be scrolled before the ring moves into the bar (about the height of the large title).
    static let collapseOffset: CGFloat = 36
}

extension EnvironmentValues {
    /// The period of the page's shared countdown ring, `nil` on pages without one.
    @Entry var passYSharedCountdownPeriod: Int?
}

extension View {
    /// Shows the page's one countdown ring: next to the large title, and in the navigation bar once the title has
    /// collapsed (or while `isCompact`, e.g. while searching). Apply it to the page's list (it follows its scroll
    /// position); the page needs a `passYCountdownClock`.
    ///
    /// - Parameters:
    ///   - period: The period of the shared ring, `nil` for none.
    ///   - subtitle: The page's subtitle under the large title (shown by this modifier in the large title block).
    ///   - isCompact: Whether the ring stays in the bar regardless of the scroll position.
    ///
    func passYSharedCountdown(period: Int?, subtitle: String?, isCompact: Bool = false) -> some View {
        modifier(PassYSharedCountdownModifier(period: period, subtitle: subtitle, isCompact: isCompact))
    }
}

/// Places the shared ring (see `passYSharedCountdown`). Only this modifier is evaluated again when the title
/// collapses or expands, not the page.
private struct PassYSharedCountdownModifier: ViewModifier {
    let period: Int?
    let subtitle: String?
    let isCompact: Bool

    /// Whether the list is scrolled past the large title.
    @SwiftUI.State private var isScrolledPastTitle = false

    /// iPhone landscape has no large title.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        let inBar = isCompact || isScrolledPastTitle || verticalSizeClass == .compact
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > PassYSharedCountdown.collapseOffset
            } action: { _, isPast in
                isScrolledPastTitle = isPast
            }
            .toolbar {
                if let period {
                    ToolbarItem(placement: .largeSubtitle) {
                        PassYSharedCountdownTitleAccessory(period: period, subtitle: subtitle, isVisible: !inBar)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        // The item stays mounted (no bar relayout); only its ring comes and goes.
                        ZStack {
                            if inBar {
                                PassYCountdownRing(
                                    period: period,
                                    size: 28,
                                    speaksSeconds: true,
                                    identifier: "SharedCountdownBar",
                                )
                                .transition(.opacity)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .animation(.easeInOut(duration: 0.2), value: inBar)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
    }
}

/// The large title's subtitle line with the shared ring at its trailing end, raised to sit beside the title.
private struct PassYSharedCountdownTitleAccessory: View {
    let period: Int
    let subtitle: String?
    let isVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if let subtitle {
                // The system's large subtitle style (same height as on the other list pages).
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            ZStack {
                if isVisible {
                    PassYCountdownRing(period: period, size: 34, speaksSeconds: true, identifier: "SharedCountdownLarge")
                        .transition(.opacity)
                }
            }
            .offset(y: -18)
            .animation(.easeInOut(duration: 0.2), value: isVisible)
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Shared countdown") {
    NavigationStack {
        List {
            ForEach(0 ..< 30) { index in
                PassYCodeRow(name: "Item \(index)", account: "me@example.test", code: "123456", period: 30) {
                    PassYIconTile(letter: "Item")
                }
            }
        }
        .passYSharedCountdown(period: 30, subtitle: "30 Items")
        .navigationTitle("Verification codes")
        .navigationSubtitle("30 Items")
        .environment(\.passYSharedCountdownPeriod, 30)
    }
}
#endif
