// Shared/PomodoroState.swift
import Foundation

struct PomodoroState: Codable, Equatable {
    var phase: PomodoroPhase
    var startDate: Date
    var endDate: Date
    var pausedAt: Date?
    var completedWorkCycles: Int
    var sessionActive: Bool

    static let idle = PomodoroState(
        phase: .work,
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: 0),
        pausedAt: nil,
        completedWorkCycles: 0,
        sessionActive: false
    )

    /// Remaining time in the current phase. Frozen at the moment of pausing
    /// rather than continuing to count down, so this matches what
    /// `Text(timerInterval:pauseTime:)` renders on screen.
    func remainingSeconds(asOf referenceDate: Date = Date()) -> TimeInterval {
        let effectiveNow = pausedAt ?? referenceDate
        return max(0, endDate.timeIntervalSince(effectiveNow))
    }

    /// "MM:SS" for the frozen remaining time while paused. Used instead of
    /// `Text(timerInterval:pauseTime:)`'s own pause handling, which has
    /// proven unreliable on this SDK — a manually formatted static string
    /// is what actually stays frozen.
    ///
    /// Rounds up (ceiling), not to nearest: `Text(timerInterval:countsDown:)`
    /// holds a number until a full second has actually elapsed (e.g. it
    /// still shows "1:31" at 90.3s remaining, not "1:30"). Rounding to
    /// nearest instead would round down whenever the pause happened to land
    /// on a sub-.5 fraction, showing one second less than what was on
    /// screen a moment earlier — which then looked like resume "added a
    /// second back" once the live display resumed and re-applied the
    /// correct ceiling.
    var formattedRemainingWhilePaused: String {
        Self.formattedRemaining(endDate: endDate, asOf: pausedAt ?? Date())
    }

    /// Shared with the Live Activity's ContentState so the two frozen
    /// displays can never round differently.
    static func formattedRemaining(endDate: Date, asOf referenceDate: Date) -> String {
        let remaining = max(0, endDate.timeIntervalSince(referenceDate))
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Durations as VoiceOver should say them ("12 minutes, 34 seconds")
/// rather than how they're drawn ("12:34", "6h 5m"), which VoiceOver reads
/// as a clock time or as letters.
enum SpokenDuration {
    static func string(_ seconds: TimeInterval, units: NSCalendar.Unit = [.minute, .second]) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = units
        formatter.zeroFormattingBehavior = .dropAll
        guard seconds.isFinite, seconds >= 1, let spoken = formatter.string(from: seconds.rounded(.up)) else {
            return "0 minutes"
        }
        return spoken
    }

    /// "Paused, 12 minutes, 34 seconds remaining" — for the frozen "12:34"
    /// shown while paused, which VoiceOver would otherwise read as a time.
    static func pausedLabel(endDate: Date, pausedAt: Date?) -> String {
        let remaining = max(0, endDate.timeIntervalSince(pausedAt ?? Date()))
        return "Paused, \(string(remaining)) remaining"
    }
}
