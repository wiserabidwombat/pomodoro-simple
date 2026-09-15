// Pomodoro/LiveActivity/LiveActivityControlling.swift
import Foundation

/// Seam around ActivityKit so TimerViewModel is unit-testable without ever
/// touching Activity<...> — the real implementation (Task 8) can only run
/// correctly on-device/in-simulator, not under XCTest.
protocol LiveActivityControlling {
    func start(state: PomodoroState, accentColor: AccentColorOption)
    func update(state: PomodoroState, accentColor: AccentColorOption)
    func end()
}

final class FakeLiveActivityController: LiveActivityControlling {
    private(set) var startedStates: [PomodoroState] = []
    private(set) var updatedStates: [PomodoroState] = []
    private(set) var endCallCount = 0

    func start(state: PomodoroState, accentColor: AccentColorOption) {
        startedStates.append(state)
    }

    func update(state: PomodoroState, accentColor: AccentColorOption) {
        updatedStates.append(state)
    }

    func end() {
        endCallCount += 1
    }
}
