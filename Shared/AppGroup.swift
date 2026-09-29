// Shared/AppGroup.swift
import Foundation

enum AppGroup {
    static let identifier = "group.com.aarontilley.pomodoro"
    static let defaults = UserDefaults(suiteName: identifier)!
}

/// The URL the Live Activity and widgets open the app with (the `pomodoro`
/// scheme is registered in Pomodoro/Info.plist). The app handles any
/// `pomodoro://` URL by switching to the Timer tab, so coming in from the
/// Lock Screen/StandBy never lands on whatever tab was last open.
enum PomodoroDeepLink {
    static let scheme = "pomodoro"
    static let timerURL = URL(string: "\(scheme)://timer")!
}
