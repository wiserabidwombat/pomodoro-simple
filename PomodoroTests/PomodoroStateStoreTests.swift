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

    func testSaveAndLoadCustomAccentColorRoundTrips() {
        let store = makeIsolatedStore()
        let custom = AccentColorOption.custom(red: 0.1, green: 0.2, blue: 0.3)
        store.save(custom)
        XCTAssertEqual(store.loadAccentColor(), custom)
    }

    func testLoadAccentColorMigratesOldRawStringFormat() {
        // Before AccentColorOption grew a custom-RGB case, it was a plain
        // String-rawValue enum saved directly (not as JSON) — confirms a
        // value saved by that old code still loads correctly.
        let suiteName = "test-suite-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("cyan", forKey: "pomodoro.accentColor")
        let store = PomodoroStateStore(defaults: defaults)
        XCTAssertEqual(store.loadAccentColor(), .cyan)
    }

    func testLoadDurationsDefaultsToClassicPomodoro() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadDurations(), .default)
    }

    // MARK: - Timer profiles

    func testFreshInstallGetsClassicAndDeepWorkWithClassicActive() {
        let store = makeIsolatedStore()
        XCTAssertEqual(store.loadProfiles(), [.classic, .deepWork])
        XCTAssertEqual(store.loadActiveProfile(), .classic)
    }

    func testUpdatingFromBeforeProfilesCarriesOldDurationsIntoClassic() {
        let suiteName = "test-suite-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let old = PomodoroDurations(workMinutes: 40, shortBreakMinutes: 8, longBreakMinutes: 20)
        defaults.set(try! JSONEncoder().encode(old), forKey: "pomodoro.durations")
        let store = PomodoroStateStore(defaults: defaults)

        let classic = store.loadProfiles().first { $0.id == TimerProfile.classicID }
        XCTAssertEqual(classic?.durations, old)
        XCTAssertEqual(store.loadDurations(), old)
    }

    func testSaveProfilesAndActiveProfileRoundTrip() {
        let store = makeIsolatedStore()
        let study = TimerProfile(name: "Study", durations: PomodoroDurations(workMinutes: 45, shortBreakMinutes: 10, longBreakMinutes: 20), sessionsBeforeLongBreak: 3)
        store.save(profiles: [.classic, study])
        store.saveActiveProfileID(study.id)

        XCTAssertEqual(store.loadProfiles(), [.classic, study])
        XCTAssertEqual(store.loadActiveProfile(), study)
        XCTAssertEqual(store.loadDurations(), study.durations)
        XCTAssertEqual(store.loadActiveProfileLabel(), "Study")
    }

    func testActiveProfileFallsBackToFirstWhenItsProfileIsGone() {
        let store = makeIsolatedStore()
        store.saveActiveProfileID(UUID())
        XCTAssertEqual(store.loadActiveProfile(), .classic)
    }

    func testProfileLabelIsHiddenWithOnlyOneProfile() {
        let store = makeIsolatedStore()
        store.save(profiles: [.classic])
        XCTAssertNil(store.loadActiveProfileLabel())
    }

    func testSessionsPerCycleIsClampedToTheSupportedRange() {
        XCTAssertEqual(TimerProfile(name: "x", durations: .default, sessionsBeforeLongBreak: 0).sessionsBeforeLongBreak, 1)
        XCTAssertEqual(TimerProfile(name: "x", durations: .default, sessionsBeforeLongBreak: 99).sessionsBeforeLongBreak, 8)
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

    func testPendingCompletedSessionsDrainInOrderAndEmptyTheQueue() {
        let store = makeIsolatedStore()
        let first = PendingCompletedSession(endedAt: Date(timeIntervalSince1970: 1_000), duration: 1500)
        let second = PendingCompletedSession(endedAt: Date(timeIntervalSince1970: 2_000), duration: 3000)
        store.enqueueCompletedSession(first)
        store.enqueueCompletedSession(second)
        XCTAssertEqual(store.drainPendingCompletedSessions(), [first, second])
        XCTAssertEqual(store.drainPendingCompletedSessions(), [])
    }

    func testRecordNaturalCompletionQueuesFocusButNotBreaks() {
        let store = makeIsolatedStore()
        let now = Date()
        recordNaturalCompletion(CompletedPhase(phase: .shortBreak, endedAt: now, duration: 300), store: store)
        XCTAssertEqual(store.drainPendingCompletedSessions(), [])
        XCTAssertEqual(store.loadCachedTodayCount(), 0)

        recordNaturalCompletion(CompletedPhase(phase: .work, endedAt: now, duration: 1500), store: store)
        XCTAssertEqual(store.drainPendingCompletedSessions(), [PendingCompletedSession(endedAt: now, duration: 1500)])
        XCTAssertEqual(store.loadCachedTodayCount(), 1)
    }

    func testRecordNaturalCompletionFromYesterdayDoesNotBumpTodaysCount() {
        let store = makeIsolatedStore()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        recordNaturalCompletion(CompletedPhase(phase: .work, endedAt: yesterday, duration: 1500), store: store)
        XCTAssertEqual(store.loadCachedTodayCount(), 0)
        XCTAssertEqual(store.drainPendingCompletedSessions().count, 1)
    }
}
