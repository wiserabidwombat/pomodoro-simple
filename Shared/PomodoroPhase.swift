// Shared/PomodoroPhase.swift
import Foundation

enum PomodoroPhase: String, Codable, CaseIterable, Hashable {
    case work
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .work: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }
}
