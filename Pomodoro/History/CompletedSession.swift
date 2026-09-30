// Pomodoro/History/CompletedSession.swift
import Foundation
import SwiftData

@Model
final class CompletedSession {
    var date: Date
    var durationSeconds: TimeInterval
    /// Which timer profile the session ran under. Optional (with nil
    /// defaults) so SwiftData migrates existing stores automatically; nil
    /// means it predates profiles and is shown as Classic.
    var profileID: UUID? = nil
    /// The profile's name at the time, so Stats can still label sessions
    /// from a profile that has since been deleted.
    var profileName: String? = nil

    init(date: Date, durationSeconds: TimeInterval, profileID: UUID? = nil, profileName: String? = nil) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.profileID = profileID
        self.profileName = profileName
    }
}
