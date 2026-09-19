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
        var formattedRemainingWhilePaused: String {
            let effectiveNow = pausedAt ?? Date()
            let total = Int(max(0, endDate.timeIntervalSince(effectiveNow)).rounded())
            return String(format: "%02d:%02d", total / 60, total % 60)
        }
    }
}
