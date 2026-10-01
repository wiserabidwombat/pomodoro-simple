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
    /// Focus sessions per cycle before the Long Break (the active profile's).
    private(set) var sessionsBeforeLongBreak: Int

    init(state: PomodoroState = .idle, durations: PomodoroDurations = .default, sessionsBeforeLongBreak: Int = 4) {
        self.state = state
        self.durations = durations
        self.sessionsBeforeLongBreak = max(1, sessionsBeforeLongBreak)
    }

    convenience init(state: PomodoroState, profile: TimerProfile) {
        self.init(state: state, durations: profile.durations, sessionsBeforeLongBreak: profile.sessionsBeforeLongBreak)
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

    /// Same "next transition only" rule as updateDurations(_:).
    func updateProfile(_ profile: TimerProfile) {
        durations = profile.durations
        sessionsBeforeLongBreak = max(1, profile.sessionsBeforeLongBreak)
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

    // MARK: - Finish early

    /// How far into a Focus session you need to be before finishing early
    /// counts it — so tapping out a minute in doesn't pad Stats.
    static let finishEarlyMinimumFraction = 0.5

    /// Focus time actually spent in the current Focus phase, pauses
    /// excluded (paused time pushes endDate back, so "planned − remaining"
    /// is exactly the time counted down). nil outside a Focus phase.
    func focusElapsed(now: Date = Date()) -> TimeInterval? {
        guard state.sessionActive, state.phase == .work else { return nil }
        let planned = durations.duration(for: .work)
        return min(planned, max(0, planned - state.remainingSeconds(asOf: now)))
    }

    /// The least Focus time that finishing early will count.
    var minimumFocusToCount: TimeInterval {
        durations.duration(for: .work) * Self.finishEarlyMinimumFraction
    }

    func canFinishEarly(now: Date = Date()) -> Bool {
        guard let elapsed = focusElapsed(now: now) else { return false }
        return elapsed >= minimumFocusToCount
    }

    /// Ends the current Focus phase now and counts it — like Skip, it moves
    /// on to the break and advances the cycle, but it also returns the
    /// session (with the time actually focused) for the caller to record.
    /// Returns nil, changing nothing, outside Focus or before the halfway
    /// point.
    @discardableResult
    func finishEarly(now: Date = Date()) -> CompletedPhase? {
        guard canFinishEarly(now: now), let elapsed = focusElapsed(now: now) else { return nil }
        let completed = CompletedPhase(phase: .work, endedAt: now, duration: elapsed)
        advancePhase()
        return completed
    }

    /// Skip as tapped outside the app (Lock Screen, StandBy, widgets, Siri),
    /// where there's no room to ask "Finish & Count It?". With
    /// `countPastHalfway`, a Focus session past the halfway mark is finished
    /// and returned for recording, exactly like finishEarly(); anything else
    /// (a break, Focus before halfway, or the setting off) is a plain skip.
    @discardableResult
    func skipFromOutsideApp(countPastHalfway: Bool, now: Date = Date()) -> CompletedPhase? {
        if countPastHalfway, let completed = finishEarly(now: now) {
            return completed
        }
        skip()
        return nil
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
            // >= rather than ==, so lowering the count mid-cycle (by
            // editing the profile) still lands on a Long Break instead of
            // running past it forever.
            nextPhase = cycles >= sessionsBeforeLongBreak ? .longBreak : .shortBreak
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
