// PomodoroTests/PomodoroModelsTests.swift
import XCTest
@testable import Pomodoro

final class PomodoroModelsTests: XCTestCase {
    func testPhaseDurations() {
        XCTAssertEqual(PomodoroPhase.work.duration, 25 * 60)
        XCTAssertEqual(PomodoroPhase.shortBreak.duration, 5 * 60)
        XCTAssertEqual(PomodoroPhase.longBreak.duration, 15 * 60)
    }

    func testPhaseDisplayNames() {
        XCTAssertEqual(PomodoroPhase.work.displayName, "Focus")
        XCTAssertEqual(PomodoroPhase.shortBreak.displayName, "Short Break")
        XCTAssertEqual(PomodoroPhase.longBreak.displayName, "Long Break")
    }

    func testRemainingSecondsWhileRunning() {
        let now = Date()
        let state = PomodoroState(phase: .work, startDate: now, endDate: now.addingTimeInterval(100), pausedAt: nil, completedWorkCycles: 0, sessionActive: true)
        XCTAssertEqual(state.remainingSeconds(asOf: now.addingTimeInterval(40)), 60, accuracy: 0.001)
    }

    func testRemainingSecondsWhilePausedIsFrozen() {
        let now = Date()
        let pausedAt = now.addingTimeInterval(30)
        let state = PomodoroState(phase: .work, startDate: now, endDate: now.addingTimeInterval(100), pausedAt: pausedAt, completedWorkCycles: 0, sessionActive: true)
        // Even asking "as of" a much later time, a paused state is frozen at pausedAt.
        XCTAssertEqual(state.remainingSeconds(asOf: now.addingTimeInterval(90)), 70, accuracy: 0.001)
    }

    func testRemainingSecondsNeverNegative() {
        let now = Date()
        let state = PomodoroState(phase: .work, startDate: now, endDate: now.addingTimeInterval(10), pausedAt: nil, completedWorkCycles: 0, sessionActive: true)
        XCTAssertEqual(state.remainingSeconds(asOf: now.addingTimeInterval(100)), 0)
    }

    func testPomodoroStateCodableRoundTrip() throws {
        let original = PomodoroState(phase: .shortBreak, startDate: Date(), endDate: Date().addingTimeInterval(300), pausedAt: Date(), completedWorkCycles: 2, sessionActive: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PomodoroState.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAccentColorOptionHasSevenPresets() {
        XCTAssertEqual(AccentColorOption.presets.count, 7)
    }

    func testCustomAccentColorRoundTripsThroughJSON() throws {
        let custom = AccentColorOption.custom(red: 0.25, green: 0.5, blue: 0.75)
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(AccentColorOption.self, from: data)
        XCTAssertEqual(decoded, custom)
    }

    func testDefaultDurationsMatchClassicPomodoro() {
        XCTAssertEqual(PomodoroDurations.default.duration(for: .work), 25 * 60)
        XCTAssertEqual(PomodoroDurations.default.duration(for: .shortBreak), 5 * 60)
        XCTAssertEqual(PomodoroDurations.default.duration(for: .longBreak), 15 * 60)
    }

    func testCustomDurationsOverrideDefaults() {
        let custom = PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30)
        XCTAssertEqual(custom.duration(for: .work), 50 * 60)
        XCTAssertEqual(custom.duration(for: .shortBreak), 10 * 60)
        XCTAssertEqual(custom.duration(for: .longBreak), 30 * 60)
    }

    func testFilledButtonTextIsDarkOnEveryPreset() {
        // All 7 presets were picked to read well on black, so they're all
        // light enough that black text out-contrasts white on them.
        for preset in AccentColorOption.presets {
            XCTAssertTrue(preset.prefersDarkText, "\(preset)")
        }
    }

    func testFilledButtonTextIsWhiteOnDarkCustomColors() {
        XCTAssertFalse(AccentColorOption.custom(red: 0, green: 0, blue: 0.4).prefersDarkText) // navy
        XCTAssertFalse(AccentColorOption.custom(red: 0.6, green: 0, blue: 0.1).prefersDarkText) // crimson
        XCTAssertFalse(AccentColorOption.custom(red: 0, green: 0, blue: 0).prefersDarkText)
    }

    func testRelativeLuminanceEndpoints() {
        XCTAssertEqual(AccentColorOption.white.relativeLuminance, 1, accuracy: 0.0001)
        XCTAssertEqual(AccentColorOption.custom(red: 0, green: 0, blue: 0).relativeLuminance, 0, accuracy: 0.0001)
    }

    func testPhaseTitleIncludesTheProfileOnlyWhenGiven() {
        XCTAssertEqual(PomodoroPhase.work.title(profileLabel: nil), "Focus")
        XCTAssertEqual(PomodoroPhase.shortBreak.title(profileLabel: "Deep Work"), "Deep Work · Short Break")
    }

    // MARK: - Accessibility text

    func testSpokenDurationSpellsOutUnits() {
        let spoken = SpokenDuration.string(12 * 60 + 34)
        XCTAssertTrue(spoken.contains("12") && spoken.contains("34") && spoken.contains("minute"), spoken)
        XCTAssertEqual(SpokenDuration.string(0), "0 minutes")
        XCTAssertEqual(SpokenDuration.string(.nan), "0 minutes")
    }

    func testPausedLabelUsesTheFrozenRemainingTime() {
        let pausedAt = Date(timeIntervalSince1970: 1_000)
        let label = SpokenDuration.pausedLabel(endDate: pausedAt.addingTimeInterval(90), pausedAt: pausedAt)
        XCTAssertTrue(label.hasPrefix("Paused, "), label)
        XCTAssertTrue(label.hasSuffix(" remaining"), label)
        XCTAssertTrue(label.contains("30"), label) // 1 minute, 30 seconds
    }

    func testProfileSpokenSummaryAvoidsSlashes() {
        XCTAssertEqual(
            TimerProfile.classic.spokenSummary,
            "25 minute focus, 5 minute short break, 15 minute long break, 4 sessions per cycle"
        )
        let single = TimerProfile(name: "One", durations: .default, sessionsBeforeLongBreak: 1)
        XCTAssertTrue(single.spokenSummary.hasSuffix("1 session per cycle"))
    }

    func testAccentColorAccessibilityNames() {
        XCTAssertEqual(AccentColorOption.purple.accessibilityName, "Purple")
        XCTAssertEqual(AccentColorOption.custom(red: 0.1, green: 0.2, blue: 0.3).accessibilityName, "Custom color")
    }

    func testOnlyDarkCustomColorsAreFlaggedAsLowContrast() {
        for preset in AccentColorOption.presets {
            XCTAssertFalse(preset.isLowContrastOnBlack, "\(preset)")
        }
        XCTAssertTrue(AccentColorOption.custom(red: 0, green: 0, blue: 0.4).isLowContrastOnBlack)
    }
}
