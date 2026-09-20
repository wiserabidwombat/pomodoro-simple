// Shared/PomodoroDurations.swift
import Foundation

struct PomodoroDurations: Codable, Equatable {
    var workMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int

    static let `default` = PomodoroDurations(workMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15)

    func duration(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .work: return TimeInterval(workMinutes * 60)
        case .shortBreak: return TimeInterval(shortBreakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        }
    }
}
