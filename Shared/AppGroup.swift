// Shared/AppGroup.swift
import Foundation

enum AppGroup {
    static let identifier = "group.com.aarontilley.pomodoro"
    static let defaults = UserDefaults(suiteName: identifier)!
}
