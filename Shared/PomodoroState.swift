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
        let total = Int(remainingSeconds(asOf: pausedAt ?? Date()).rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
