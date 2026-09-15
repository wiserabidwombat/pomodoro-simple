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
    }
}
