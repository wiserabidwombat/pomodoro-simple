// Shared/TimerProfile.swift
import Foundation

/// A named, saved timer setup ("Deep Work", "Study", ...): the three phase
/// lengths plus how many Focus sessions make up a cycle before the Long
/// Break. Stored as JSON in the App Group so the app, the Live Activity
/// intents, and the widget all read the same active profile.
struct TimerProfile: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var durations: PomodoroDurations
    /// Focus sessions per cycle; the last one is followed by the Long Break.
    var sessionsBeforeLongBreak: Int

    static let sessionsRange = 1...8

    init(id: UUID = UUID(), name: String, durations: PomodoroDurations, sessionsBeforeLongBreak: Int) {
        self.id = id
        self.name = name
        self.durations = durations
        self.sessionsBeforeLongBreak = min(max(sessionsBeforeLongBreak, Self.sessionsRange.lowerBound), Self.sessionsRange.upperBound)
    }

    /// Fixed ids so the built-in profiles are stable across launches — and
    /// so history recorded before profiles existed (which has no profile
    /// on it) can be attributed to Classic, the setup it actually ran under.
    static let classicID = UUID(uuidString: "5A1E0C1A-0000-4000-8000-000000000001")!
    static let deepWorkID = UUID(uuidString: "5A1E0C1A-0000-4000-8000-000000000002")!

    static let classic = TimerProfile(
        id: classicID,
        name: "Classic",
        durations: .default,
        sessionsBeforeLongBreak: 4
    )

    static let deepWork = TimerProfile(
        id: deepWorkID,
        name: "Deep Work",
        durations: PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30),
        sessionsBeforeLongBreak: 2
    )
}

extension TimerProfile {
    /// e.g. "25 / 5 / 15 min · 4 per cycle"
    var summary: String {
        "\(durations.workMinutes) / \(durations.shortBreakMinutes) / \(durations.longBreakMinutes) min · \(sessionsBeforeLongBreak) per cycle"
    }
}
