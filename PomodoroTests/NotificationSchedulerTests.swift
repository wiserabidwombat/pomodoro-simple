// PomodoroTests/NotificationSchedulerTests.swift
import XCTest
@testable import Pomodoro

final class NotificationSchedulerTests: XCTestCase {
    func testBodyTextForWorkPhase() {
        XCTAssertEqual(NotificationScheduler.body(for: .work), "Focus session complete. Time for a break.")
    }

    func testBodyTextForBreaks() {
        XCTAssertEqual(NotificationScheduler.body(for: .shortBreak), "Break's over. Back to focus.")
        XCTAssertEqual(NotificationScheduler.body(for: .longBreak), "Break's over. Back to focus.")
    }
}
