// Shared/PomodoroActivityAttributes.swift
import ActivityKit
import Foundation

struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phase: PomodoroPhase
        var startDate: Date
        var endDate: Date
        var pausedAt: Date?
        var accentColor: AccentColorOption

        /// "MM:SS" for the frozen remaining time while paused. Used instead
        /// of `Text(timerInterval:pauseTime:)`'s own pause handling, which
        /// has proven unreliable on this SDK.
        ///
        /// Rounds up (ceiling), not to nearest — see PomodoroState's
        /// matching property for why: `Text(timerInterval:countsDown:)`
        /// holds a number until a full second has actually elapsed, so
        /// rounding to nearest would occasionally show one second less than
        /// what was just on screen, making resume look like it added a
        /// second back.
        var formattedRemainingWhilePaused: String {
            let effectiveNow = pausedAt ?? Date()
            let total = Int(max(0, endDate.timeIntervalSince(effectiveNow)).rounded(.up))
            return String(format: "%02d:%02d", total / 60, total % 60)
        }
    }
}
