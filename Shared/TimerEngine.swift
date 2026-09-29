// Shared/TimerEngine.swift
import Foundation

/// A phase that just ran out on its own (as opposed to being skipped).
/// Returned by `TimerEngine.catchUpIfExpired()` so callers can tell *any*
/// natural phase change (alert + persist) apart from a completed Focus
/// session specifically (also record it in history).
struct CompletedPhase: Equatable {
    let phase: PomodoroPhase
    /// When the phase actually ran out — not when this process noticed.
    /// History is dated by this, so a Focus session that ended at 11:50pm
    /// still counts toward that day even if the app isn't opened until
    /// the next morning.
    let endedAt: Date
    let duration: TimeInterval
}

final class TimerEngine {
    private(set) var state: PomodoroState
    private(set) var durations: PomodoroDurations

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

    /// If the phase's end has passed while running (not paused), advances it
    /// and returns what just completed — for *every* phase, breaks included.
    /// (This used to return completeCurrentPhase()'s "was it Focus?" Bool,
    /// which made an expired break look like "nothing happened": the
    /// in-app ticker then never persisted the advance, re-read the still-
    /// expired break from the store a second later, advanced it again, and
    /// so on — restarting the next Focus countdown and replaying the
    /// phase-change chime every second.)
    ///
    /// Used to catch up state that changed while this process wasn't looking
    /// (app backgrounded, or a Lock Screen/widget intent mutated shared
    /// state last).
    @discardableResult
    func catchUpIfExpired(now: Date = Date()) -> CompletedPhase? {
        guard state.sessionActive, state.pausedAt == nil, now >= state.endDate else { return nil }
        let completed = CompletedPhase(
            phase: state.phase,
            endedAt: state.endDate,
            duration: durations.duration(for: state.phase)
        )
        completeCurrentPhase()
        return completed
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
