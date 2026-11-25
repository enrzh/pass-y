import BitwardenKit
import BitwardenKitMocks
import Foundation
import Testing

@testable import BitwardenShared

// MARK: - PassYOneTimeCode

struct PassYOneTimeCodeTests {
    /// Codes are split into two groups; an odd length puts the shorter group first.
    @Test
    func groups_splitInTwo() {
        #expect(PassYOneTimeCode.groups("123456") == ["123", "456"])
        #expect(PassYOneTimeCode.groups("12345678") == ["1234", "5678"])
        #expect(PassYOneTimeCode.groups("1234567") == ["123", "4567"])
        #expect(PassYOneTimeCode.groups("12345") == ["12", "345"])
        #expect(PassYOneTimeCode.groups("1234") == ["12", "34"])
    }

    /// Short and empty codes are not split; white space in the input is ignored.
    @Test
    func groups_shortEmptyAndSpaced() {
        #expect(PassYOneTimeCode.groups("123") == ["123"])
        #expect(PassYOneTimeCode.groups("") == [])
        #expect(PassYOneTimeCode.groups("123 456") == ["123", "456"])
    }

    /// The display form joins the two groups with one space.
    @Test
    func display() {
        #expect(PassYOneTimeCode.display("123456") == "123 456")
        #expect(PassYOneTimeCode.display("ABCDE") == "AB CDE")
    }

    /// VoiceOver reads every character on its own.
    @Test
    func spoken() {
        #expect(PassYOneTimeCode.spoken("123456") == "1 2 3 4 5 6")
        #expect(PassYOneTimeCode.spoken("123 456") == "1 2 3 4 5 6")
    }

    /// The masked placeholder has the shape of a six-digit code.
    @Test
    func masked() {
        #expect(PassYOneTimeCode.masked() == "••• •••")
    }

    /// The row label reads name, account, spaced digits and the seconds left; a locked code says so.
    @Test
    func accessibilityLabel() {
        #expect(
            PassYOneTimeCode.accessibilityLabel(name: "GitHub", account: "octo", code: "123456", secondsRemaining: 14)
                == "GitHub, octo, Code 1 2 3 4 5 6, 14 seconds left",
        )
        #expect(
            PassYOneTimeCode.accessibilityLabel(name: "GitHub", account: nil, code: "123456", secondsRemaining: 1)
                == "GitHub, Code 1 2 3 4 5 6, 1 second left",
        )
        #expect(
            PassYOneTimeCode.accessibilityLabel(name: "Bank", account: "", code: nil, secondsRemaining: 9)
                == "Bank, Code hidden, master password required",
        )
    }
}

// MARK: - PassYCountdown

struct PassYCountdownTests {
    /// Seconds left round up and the fraction follows the period.
    @Test
    func remainingAndFraction() {
        let start = PassYCountdown(period: 30, date: Date(timeIntervalSinceReferenceDate: 30_000 + 0))
        #expect(start.secondsRemaining == 30)
        #expect(start.fractionRemaining == 1)

        let middle = PassYCountdown(period: 30, date: Date(timeIntervalSinceReferenceDate: 30_000 + 15))
        #expect(middle.secondsRemaining == 15)
        #expect(abs(middle.fractionRemaining - 0.5) < 0.0001)

        let almost = PassYCountdown(period: 30, date: Date(timeIntervalSinceReferenceDate: 30_000 + 29.5))
        #expect(almost.secondsRemaining == 1)
        #expect(almost.fractionRemaining > 0 && almost.fractionRemaining < 0.05)
    }

    /// A zero or negative period is treated as one second (no division by zero, values stay in range).
    @Test
    func invalidPeriod() {
        let countdown = PassYCountdown(period: 0, date: Date(timeIntervalSinceReferenceDate: 30_000 + 10.25))
        #expect(countdown.period == 1)
        #expect((0 ... 1).contains(countdown.secondsRemaining))
        #expect((0 ... 1).contains(countdown.fractionRemaining))
    }

    /// Normal above 5 seconds, orange from 5 to 3, red from 2 down.
    @Test
    func toneThresholds() {
        #expect(PassYCountdown.tone(secondsRemaining: 30) == .normal)
        #expect(PassYCountdown.tone(secondsRemaining: 6) == .normal)
        #expect(PassYCountdown.tone(secondsRemaining: 5) == .warning)
        #expect(PassYCountdown.tone(secondsRemaining: 3) == .warning)
        #expect(PassYCountdown.tone(secondsRemaining: 2) == .critical)
        #expect(PassYCountdown.tone(secondsRemaining: 0) == .critical)
        #expect(PassYCountdown(period: 30, date: Date(timeIntervalSinceReferenceDate: 30_000 + 26)).tone == .warning)
        #expect(PassYCountdown(period: 30, date: Date(timeIntervalSinceReferenceDate: 30_000 + 29)).tone == .critical)
    }

    /// The shared clock reads its time provider on every tick.
    @Test
    @MainActor
    func clockTicksFromTimeProvider() {
        let timeProvider = MockTimeProvider(.mockTime(Date(timeIntervalSinceReferenceDate: 30_000 + 100)))
        let clock = PassYCountdownClock(timeProvider: timeProvider)
        #expect(clock.now == Date(timeIntervalSinceReferenceDate: 30_000 + 100))
        timeProvider.timeConfig = .mockTime(Date(timeIntervalSinceReferenceDate: 30_000 + 101))
        clock.tick()
        #expect(clock.now == Date(timeIntervalSinceReferenceDate: 30_000 + 101))
        clock.start()
        clock.stop()
    }
}

// MARK: - PassYTilePalette

struct PassYTilePaletteTests {
    /// A name always gets the same palette colour (stable across launches), case and outer spaces ignored.
    @Test
    func index_isStable() {
        #expect(PassYTilePalette.index(for: "GitHub") == PassYTilePalette.index(for: "github"))
        #expect(PassYTilePalette.index(for: " GitHub ") == PassYTilePalette.index(for: "GitHub"))
        // djb2 of "github" modulo the palette size: a fixed value, not Swift's per-launch random hash.
        var hash: UInt64 = 5381
        for scalar in "github".unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
        #expect(PassYTilePalette.index(for: "GitHub") == Int(hash % UInt64(PassYTilePalette.colors.count)))
        #expect((0 ..< PassYTilePalette.colors.count).contains(PassYTilePalette.index(for: "")))
    }

    /// The initial is the first letter or digit, upper-cased; "?" without one.
    @Test
    func initial() {
        #expect(PassYTilePalette.initial(of: "github") == "G")
        #expect(PassYTilePalette.initial(of: "  (1Password)") == "1")
        #expect(PassYTilePalette.initial(of: "ärzte") == "Ä")
        #expect(PassYTilePalette.initial(of: " - ") == "?")
    }

    /// Tiles grow with Dynamic Type, at most to 1.6 times their size, never below it.
    @Test
    func scaledTileSide() {
        #expect(PassYDesign.IconSize.scaled(40, by: 1) == 40)
        #expect(PassYDesign.IconSize.scaled(40, by: 0.8) == 40)
        #expect(PassYDesign.IconSize.scaled(40, by: 1.25) == 50)
        #expect(PassYDesign.IconSize.scaled(40, by: 3) == 64)
    }
}
