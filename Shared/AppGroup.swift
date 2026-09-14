// Shared/AppGroup.swift
import Foundation

enum AppGroup {
    static let identifier = "group.com.example.pomodoro"
    static let defaults = UserDefaults(suiteName: identifier)!
}
