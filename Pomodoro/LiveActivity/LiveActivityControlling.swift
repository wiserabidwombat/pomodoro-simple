// Pomodoro/LiveActivity/LiveActivityControlling.swift
import Foundation

/// Seam around ActivityKit so TimerViewModel is unit-testable without ever
/// touching Activity<...> — the real implementation (Task 8) can only run
/// correctly on-device/in-simulator, not under XCTest.
protocol LiveActivityControlling {
    /// True when there's no live, healthy Activity to push updates to (none
    /// exists, or the system has already ended/dismissed one) — the caller
    /// should request a fresh Activity instead of updating a corpse. `.stale`
    /// does NOT count as needing a restart: that state just means our own
    /// staleDate has passed, and a plain update() clears it.
    var needsRestart: Bool { get }
    func start(state: PomodoroState, accentColor: AccentColorOption)
    func update(state: PomodoroState, accentColor: AccentColorOption)
    func end()
}

final class FakeLiveActivityController: LiveActivityControlling {
    private(set) var startedStates: [PomodoroState] = []
    private(set) var updatedStates: [PomodoroState] = []
    private(set) var endCallCount = 0
    var needsRestart = true

    func start(state: PomodoroState, accentColor: AccentColorOption) {
        startedStates.append(state)
        needsRestart = false
    }

    func update(state: PomodoroState, accentColor: AccentColorOption) {
        updatedStates.append(state)
    }

    func end() {
        endCallCount += 1
        needsRestart = true
    }
}
