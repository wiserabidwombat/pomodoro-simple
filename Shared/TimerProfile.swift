// Shared/TimerProfile.swift
import AppIntents
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

    /// The next `count` phases after the current one, following the same
    /// rules as TimerEngine (a Long Break after the cycle's last Focus
    /// session). With no session running, starts from the Focus session
    /// that Start would begin. For the iPad's "Up next" card.
    func upcomingPhases(after state: PomodoroState, count: Int = 2) -> [PomodoroPhase] {
        var phase: PomodoroPhase
        var cycles = state.completedWorkCycles
        var result: [PomodoroPhase] = []
        if state.sessionActive {
            phase = state.phase
        } else {
            // Start begins a fresh cycle with Focus; that's what's next.
            phase = .work
            cycles = 0
            result.append(.work)
        }
        while result.count < count {
            switch phase {
            case .work:
                cycles += 1
                phase = cycles >= sessionsBeforeLongBreak ? .longBreak : .shortBreak
            case .shortBreak:
                phase = .work
            case .longBreak:
                cycles = 0
                phase = .work
            }
            result.append(phase)
        }
        return result
    }

    /// The same, as VoiceOver should read it — "25 / 5 / 15 min" is read
    /// out as "25 slash 5 slash 15 min".
    var spokenSummary: String {
        let sessions = sessionsBeforeLongBreak == 1 ? "1 session" : "\(sessionsBeforeLongBreak) sessions"
        return "\(durations.workMinutes) minute focus, \(durations.shortBreakMinutes) minute short break, \(durations.longBreakMinutes) minute long break, \(sessions) per cycle"
    }
}

/// A timer profile as Siri, Shortcuts, and the Action Button see it. Only
/// the id and name cross over; the durations are always read fresh from
/// the App Group when a session actually starts.
struct TimerProfileEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer Profile"
    static var defaultQuery = TimerProfileQuery()

    let id: UUID
    let name: String

    init(_ profile: TimerProfile) {
        id = profile.id
        name = profile.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Lets Siri and Shortcuts list the user's profiles and match one by name
/// ("Start Deep Work…").
struct TimerProfileQuery: EntityStringQuery {
    init() {}

    func entities(for identifiers: [UUID]) async throws -> [TimerProfileEntity] {
        PomodoroStateStore().loadProfiles()
            .filter { identifiers.contains($0.id) }
            .map(TimerProfileEntity.init)
    }

    func entities(matching string: String) async throws -> [TimerProfileEntity] {
        PomodoroStateStore().loadProfiles()
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(TimerProfileEntity.init)
    }

    func suggestedEntities() async throws -> [TimerProfileEntity] {
        PomodoroStateStore().loadProfiles().map(TimerProfileEntity.init)
    }
}
