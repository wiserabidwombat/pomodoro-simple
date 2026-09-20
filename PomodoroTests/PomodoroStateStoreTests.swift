// PomodoroTests/PomodoroStateStoreTests.swift
import XCTest
@testable import Pomodoro

final class PomodoroStateStoreTests: XCTestCase {
    private func makeIsolatedStore() -> PomodoroStateStore {
        let suiteName = "test-suite-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return PomodoroStateStore(defaults: defaults)
    }

    func testLoadStateDefaultsToIdleWhenNothingSaved() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadState(), .idle)
    }

    func testSaveAndLoadStateRoundTrips() {
        let store = makeIsolatedStore()
        let state = PomodoroState(phase: .shortBreak, startDate: Date(), endDate: Date().addingTimeInterval(120), pausedAt: nil, completedWorkCycles: 3, sessionActive: true)
        store.save(state)
        XCTAssertEqual(store.loadState(), state)
    }

    func testLoadAccentColorDefaultsToWhite() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadAccentColor(), .white)
    }

    func testSaveAndLoadAccentColorRoundTrips() {
        let store = makeIsolatedStore()
        store.save(AccentColorOption.purple)
        XCTAssertEqual(store.loadAccentColor(), .purple)
    }

    func testLoadDurationsDefaultsToClassicPomodoro() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadDurations(), .default)
    }

    func testSaveAndLoadDurationsRoundTrips() {
        let store = makeIsolatedStore()
        let durations = PomodoroDurations(workMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30)
        store.save(durations)
        XCTAssertEqual(store.loadDurations(), durations)
    }

    func testLoadSilenceDuringFocusDefaultsToFalse() {
        let store = makeIsolatedStore()
        XCTAssertFalse(store.loadSilenceDuringFocus())
    }

    func testSaveAndLoadSilenceDuringFocusRoundTrips() {
        let store = makeIsolatedStore()
        store.save(silenceDuringFocus: true)
        XCTAssertTrue(store.loadSilenceDuringFocus())
    }

    func testLoadSoundEnabledDefaultsToTrue() {
        let store = makeIsolatedStore()
        XCTAssertTrue(store.loadSoundEnabled())
    }

    func testSaveAndLoadSoundEnabledRoundTrips() {
        let store = makeIsolatedStore()
        store.save(soundEnabled: false)
        XCTAssertFalse(store.loadSoundEnabled())
    }

    func testLoadChimeDefaultsToDefault() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadChime(), .default)
    }

    func testSaveAndLoadChimeRoundTrips() {
        let store = makeIsolatedStore()
        store.save(ChimeOption.chime6)
        XCTAssertEqual(store.loadChime(), .chime6)
    }

    func testLoadCachedTodayCountDefaultsToZero() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadCachedTodayCount(), 0)
    }

    func testIncrementCachedTodayCountAccumulatesOnSameDay() {
        let store = makeIsolatedStore()
        let now = Date()
        store.incrementCachedTodayCount(now: now)
        store.incrementCachedTodayCount(now: now)
        store.incrementCachedTodayCount(now: now)
        XCTAssertEqual(store.loadCachedTodayCount(now: now), 3)
    }

    func testCachedTodayCountResetsOnNewDay() {
        let store = makeIsolatedStore()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        store.incrementCachedTodayCount(now: yesterday)
        store.incrementCachedTodayCount(now: yesterday)
        XCTAssertEqual(store.loadCachedTodayCount(now: Date()), 0)
    }
}
