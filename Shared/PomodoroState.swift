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
}
