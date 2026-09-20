// Shared/TimerEngine.swift
import Foundation

final class TimerEngine {
    private(set) var state: PomodoroState
    private var durations: PomodoroDurations

    init(state: PomodoroState = .idle, durations: PomodoroDurations = .default) {
        self.state = state
        self.durations = durations
    }

    func reload(_ newState: PomodoroState) {
        state = newState
    }

    /// Only affects the *next* phase transition — the currently running
    /// phase's endDate was already fixed when it started, so changing this
    /// mid-session doesn't yank the countdown to a new length underfoot.
    func updateDurations(_ durations: PomodoroDurations) {
        self.durations = durations
    }

    func start() {
        let now = Date()
        state = PomodoroState(
            phase: .work,
            startDate: now,
            endDate: now.addingTimeInterval(durations.duration(for: .work)),
            pausedAt: nil,
            completedWorkCycles: 0,
            sessionActive: true
        )
    }

    func pause() {
        guard state.sessionActive, state.pausedAt == nil else { return }
        state.pausedAt = Date()
    }

    func resume() {
        guard let pausedAt = state.pausedAt else { return }
        let pauseDuration = Date().timeIntervalSince(pausedAt)
        state.endDate = state.endDate.addingTimeInterval(pauseDuration)
        state.pausedAt = nil
    }

    func skip() {
        guard state.sessionActive else { return }
        advancePhase()
    }

    /// Stops the current session entirely and returns to the initial idle
    /// state — back to Work phase, cycle count reset to 0, not running.
    func reset() {
        state = .idle
    }

    /// Call when the current phase's countdown naturally reaches zero.
    /// Returns true if a work phase was just completed (caller records history for that).
    @discardableResult
    func completeCurrentPhase() -> Bool {
        guard state.sessionActive else { return false }
        let wasWork = state.phase == .work
        advancePhase()
        return wasWork
    }

    /// If the phase's end has passed while running (not paused), advances it.
    /// Used to catch up state that changed while this process wasn't looking
    /// (app backgrounded, or a different process — app vs. widget extension —
    /// mutated shared state last).
    @discardableResult
    func catchUpIfExpired(now: Date = Date()) -> Bool {
        guard state.sessionActive, state.pausedAt == nil, now >= state.endDate else { return false }
        return completeCurrentPhase()
    }

    private func advancePhase() {
        let now = Date()
        var cycles = state.completedWorkCycles
        let nextPhase: PomodoroPhase

        switch state.phase {
        case .work:
            cycles += 1
            nextPhase = cycles.isMultiple(of: 4) ? .longBreak : .shortBreak
        case .shortBreak:
            nextPhase = .work
        case .longBreak:
            cycles = 0
            nextPhase = .work
        }

        state = PomodoroState(
            phase: nextPhase,
            startDate: now,
            endDate: now.addingTimeInterval(durations.duration(for: nextPhase)),
            pausedAt: nil,
            completedWorkCycles: cycles,
            sessionActive: true
        )
    }
}
