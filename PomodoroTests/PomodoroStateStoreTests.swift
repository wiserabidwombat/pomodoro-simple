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
}
