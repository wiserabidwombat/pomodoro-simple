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
        XCTAssertFalse(engine.catchUpIfExpired(now: engine.state.startDate))
        XCTAssertEqual(engine.state.phase, .work)
    }

    func testCatchUpIfExpiredAdvancesWhenPast() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        let pastEnd = engine.state.endDate.addingTimeInterval(1)
        XCTAssertTrue(engine.catchUpIfExpired(now: pastEnd))
        XCTAssertEqual(engine.state.phase, .shortBreak)
    }

    func testCatchUpIfExpiredNoOpsWhilePaused() {
        let engine = TimerEngine(state: .idle)
        engine.start()
        engine.pause()
        let farFuture = engine.state.endDate.addingTimeInterval(1000)
        XCTAssertFalse(engine.catchUpIfExpired(now: farFuture))
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
}
