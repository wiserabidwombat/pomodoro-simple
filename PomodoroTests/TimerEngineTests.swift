// PomodoroTests/TimerEngineTests.swift
import XCTest
@testable import Pomodoro

final class TimerEngineTests: XCTestCase {
    func testStartBeginsWorkPhase() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        XCTAssertEqual(engine.state.phase, .work)
        XCTAssertTrue(engine.state.sessionActive)
        XCTAssertNil(engine.state.pausedAt)
        XCTAssertEqual(engine.state.completedWorkCycles, 0)
        XCTAssertEqual(engine.state.endDate.timeIntervalSince(engine.state.startDate), PomodoroPhase.work.duration, accuracy: 0.01)
    }

    func testPauseSetsPausedAt() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.pause()
        XCTAssertNotNil(engine.state.pausedAt)
    }

    func testResumePreservesRemainingTime() {
        let now = Date()
        let running = PomodoroState(phase: .work, startDate: now, endDate: now.addingTimeInterval(100), pausedAt: nil, completedWorkCycles: 0, sessionActive: true)
        let engine = TimerEngine(state: running)
        let pausedAt = now.addingTimeInterval(20)
        // Simulate pausing 20s in.
        engine.reload(PomodoroState(phase: .work, startDate: now, endDate: now.addingTimeInterval(100), pausedAt: pausedAt, completedWorkCycles: 0, sessionActive: true))
        let remainingAtPause = engine.state.remainingSeconds(asOf: pausedAt)
        // resume() anchors the new end date to the actual wall-clock moment it is
        // called (plus the frozen remaining time), so measure 10s forward from that
        // real call time rather than from the synthetic `pausedAt` above.
        let resumedAt = Date()
        engine.resume()
        XCTAssertEqual(engine.state.remainingSeconds(asOf: resumedAt.addingTimeInterval(10)), remainingAtPause - 10, accuracy: 0.5)
        XCTAssertNil(engine.state.pausedAt)
    }

    func testSkipCyclesThroughShortBreaksThenLongBreak() {
        let engine = TimerEngine(state: .idle)
        engine.start()

        engine.skip() // work #1 -> shortBreak
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.completedWorkCycles, 1)

        engine.skip() // shortBreak -> work #2
        engine.skip() // work #2 -> shortBreak
        XCTAssertEqual(engine.state.completedWorkCycles, 2)

        engine.skip() // shortBreak -> work #3
        engine.skip() // work #3 -> shortBreak
        XCTAssertEqual(engine.state.completedWorkCycles, 3)

        engine.skip() // shortBreak -> work #4
        engine.skip() // work #4 -> longBreak
        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.state.completedWorkCycles, 4)

        engine.skip() // longBreak -> work, cycles reset
        XCTAssertEqual(engine.state.phase, .work)
        XCTAssertEqual(engine.state.completedWorkCycles, 0)
    }

    func testCompleteCurrentPhaseReturnsTrueOnlyForWork() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        XCTAssertTrue(engine.completeCurrentPhase())
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertFalse(engine.completeCurrentPhase())
    }

    func testCatchUpIfExpiredNoOpsWhenNotExpired() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        XCTAssertNil(engine.catchUpIfExpired(now: engine.state.startDate))
        XCTAssertEqual(engine.state.phase, .work)
    }

    func testCatchUpIfExpiredAdvancesWhenPast() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        let workEnd = engine.state.endDate
        let completed = engine.catchUpIfExpired(now: workEnd.addingTimeInterval(1))
        XCTAssertEqual(completed?.phase, .work)
        XCTAssertEqual(completed?.endedAt, workEnd)
        XCTAssertEqual(completed?.duration, PomodoroDurations.default.duration(for: .work))
        XCTAssertEqual(engine.state.phase, .shortBreak)
    }

    func testCatchUpIfExpiredReportsAnExpiredBreakToo() {
        // Regression: an expired break used to report "nothing happened",
        // so the app never persisted the advance and redid it every tick.
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.skip() // -> shortBreak
        let completed = engine.catchUpIfExpired(now: engine.state.endDate.addingTimeInterval(1))
        XCTAssertEqual(completed?.phase, .shortBreak)
        XCTAssertEqual(engine.state.phase, .work)
    }

    func testCatchUpIfExpiredRecordsTheCustomFocusLength() {
        let engine = TimerEngine(state: .idle, durations: PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30))
        engine.start()
        let completed = engine.catchUpIfExpired(now: engine.state.endDate)
        XCTAssertEqual(completed?.duration, 50 * 60)
    }

    func testCatchUpIfExpiredNoOpsWhilePaused() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.pause()
        let farFuture = engine.state.endDate.addingTimeInterval(1000)
        XCTAssertNil(engine.catchUpIfExpired(now: farFuture))
    }

    func testStartUsesCustomWorkDuration() {
        let engine = TimerEngine(state: .idle, durations: PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30))
        engine.start()
        XCTAssertEqual(engine.state.endDate.timeIntervalSince(engine.state.startDate), 50 * 60, accuracy: 0.01)
    }

    func testUpdateDurationsAffectsNextPhaseNotCurrentOne() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        let originalEndDate = engine.state.endDate
        engine.updateDurations(PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30))
        // Currently running Work phase is untouched by the update.
        XCTAssertEqual(engine.state.endDate, originalEndDate)
        // But the next phase (Short Break) picks up the new duration.
        engine.skip()
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.endDate.timeIntervalSince(engine.state.startDate), 10 * 60, accuracy: 0.01)
    }

    func testResetReturnsToIdle() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.skip()
        engine.skip()
        engine.pause()
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
    }

    func testProfileWithTwoSessionsPerCycleReachesLongBreakAfterTheSecond() {
        let engine = TimerEngine(state: .idle, profile: .deepWork)
        engine.start()
        XCTAssertEqual(engine.state.endDate.timeIntervalSince(engine.state.startDate), 50 * 60, accuracy: 0.01)
        engine.skip() // work #1 -> shortBreak
        XCTAssertEqual(engine.state.phase, .shortBreak)
        engine.skip() // -> work #2
        engine.skip() // work #2 -> longBreak
        XCTAssertEqual(engine.state.phase, .longBreak)
        XCTAssertEqual(engine.state.endDate.timeIntervalSince(engine.state.startDate), 30 * 60, accuracy: 0.01)
        engine.skip() // longBreak -> work, cycle resets
        XCTAssertEqual(engine.state.completedWorkCycles, 0)
    }

    func testLoweringSessionsPerCycleMidCycleStillLandsOnALongBreak() {
        let engine = TimerEngine(state: .idle, profile: .classic)
        engine.start()
        engine.skip() // work #1 -> shortBreak (cycles = 1)
        engine.skip() // -> work #2
        engine.updateProfile(TimerProfile(name: "Short", durations: .default, sessionsBeforeLongBreak: 1))
        engine.skip() // work #2 done, cycles = 2 >= 1
        XCTAssertEqual(engine.state.phase, .longBreak)
    }

    // MARK: - Finish early

    func testFinishEarlyPastHalfwayCountsTheTimeActuallyFocused() {
        let engine = TimerEngine(state: .idle) // 25-minute Focus
        engine.start()
        let twentyMinutesIn = engine.state.startDate.addingTimeInterval(20 * 60)

        let completed = engine.finishEarly(now: twentyMinutesIn)

        XCTAssertEqual(completed?.phase, .work)
        XCTAssertEqual(completed?.duration ?? 0, 20 * 60, accuracy: 0.5)
        XCTAssertEqual(completed?.endedAt, twentyMinutesIn)
        XCTAssertEqual(engine.state.phase, .shortBreak)
        XCTAssertEqual(engine.state.completedWorkCycles, 1) // counts toward the cycle
    }

    func testFinishEarlyBeforeHalfwayDoesNothing() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        let fiveMinutesIn = engine.state.startDate.addingTimeInterval(5 * 60)
        XCTAssertFalse(engine.canFinishEarly(now: fiveMinutesIn))
        XCTAssertNil(engine.finishEarly(now: fiveMinutesIn))
        XCTAssertEqual(engine.state.phase, .work)
    }

    func testFinishEarlyIsOnlyForFocus() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.skip() // -> shortBreak
        XCTAssertNil(engine.focusElapsed())
        XCTAssertNil(engine.finishEarly(now: engine.state.endDate))
        XCTAssertEqual(engine.state.phase, .shortBreak)
    }

    func testFocusElapsedExcludesPausedTime() {
        let now = Date()
        // Paused 15 minutes into a 25-minute Focus (10 left), and the pause
        // has lasted a while since — elapsed must stay frozen at 15.
        let paused = PomodoroState(
            phase: .work,
            startDate: now.addingTimeInterval(-40 * 60),
            endDate: now.addingTimeInterval(-15 * 60 + 10 * 60),
            pausedAt: now.addingTimeInterval(-15 * 60),
            completedWorkCycles: 0,
            sessionActive: true
        )
        let engine = TimerEngine(state: paused)
        XCTAssertEqual(engine.focusElapsed(now: now) ?? 0, 15 * 60, accuracy: 0.5)
    }
}
