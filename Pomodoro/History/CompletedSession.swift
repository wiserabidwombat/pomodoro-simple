// Pomodoro/History/CompletedSession.swift
import Foundation
import SwiftData

@Model
final class CompletedSession {
    var date: Date
    var durationSeconds: TimeInterval

    init(date: Date, durationSeconds: TimeInterval) {
        self.date = date
        self.durationSeconds = durationSeconds
    }
}
