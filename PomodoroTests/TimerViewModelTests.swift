// PomodoroTests/TimerViewModelTests.swift
import XCTest
import SwiftData
@testable import Pomodoro

@MainActor
final class TimerViewModelTests: XCTestCase {
    private func makeViewModel() -> (TimerViewModel, FakeLiveActivityController, FakePhaseChangeAlert, PomodoroStateStore, HistoryStore) {
        let suiteName = "test-suite-\(UUID().uuidString)"
        let store = PomodoroStateStore(defaults: UserDefaults(suiteName: suiteName)!)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: CompletedSession.self, configurations: config)
        let history = HistoryStore(context: container.mainContext)
        let fakeActivity = FakeLiveActivityController()
        let fakeAlert = FakePhaseChangeAlert()
        let vm = TimerViewModel(store: store, notifications: NotificationScheduler(), historyStore: history, liveActivity: fakeActivity, alerting: fakeAlert, watchSync: FakeWatchSync())
        return (vm, fakeActivity, fakeAlert, store, history)
    }

    func testStartActivatesSessionAndStartsLiveActivity() {
        let (vm, fakeActivity, _, store, _) = makeViewModel()
        vm.start()
        XCTAssertTrue(vm.state.sessionActive)
        XCTAssertEqual(vm.state.phase, .work)
        XCTAssertEqual(fakeActivity.startedStates.count, 1)
        XCTAssertEqual(store.loadState(), vm.state)
    }

    func testPauseAndResumeUpdateLiveActivityAndPersist() {
        let (vm, fakeActivity, _, store, _) = makeViewModel()
        vm.start()
        vm.pause()
        XCTAssertNotNil(vm.state.pausedAt)
        XCTAssertEqual(store.loadState().pausedAt, vm.state.pausedAt)

        vm.resume()
        XCTAssertNil(vm.state.pausedAt)
        XCTAssertTrue(fakeActivity.updatedStates.count >= 2)
    }

    func testSkipAdvancesPhaseAndPersists() {
        let (vm, _, _, store, _) = makeViewModel()
        vm.start()
        vm.skip()
        XCTAssertEqual(vm.state.phase, .shortBreak)
        XCTAssertEqual(store.loadState().phase, .shortBreak)
    }

    func testSkipDoesNotTriggerPhaseChangeAlert() {
        // Skip is a deliberate user action, not a "time's up" event — it
        // should not play the completion alert.
        let (vm, _, fakeAlert, _, _) = makeViewModel()
        vm.start()
        vm.skip()
        XCTAssertEqual(fakeAlert.alertCount, 0)
    }

    func testRefreshFromSharedStatePicksUpChangeMadeByAnotherProcess() {
        let (vm, _, _, store, _) = makeViewModel()
        vm.start()
        // Simulate the widget extension's Pause intent writing to the shared store
        // directly, independent of this TimerViewModel's in-memory engine.
        var externallyPaused = store.loadState()
        externallyPaused.pausedAt = Date()
        store.save(externallyPaused)

        vm.refreshFromSharedState()
        XCTAssertNotNil(vm.state.pausedAt)
    }

    func testRestartResetsToIdleAndEndsLiveActivity() {
        let (vm, fakeActivity, _, store, _) = makeViewModel()
        vm.start()
        vm.skip()
        vm.pause()

        vm.restart()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(store.loadState(), .idle)
        XCTAssertEqual(fakeActivity.endCallCount, 1)
    }

    func testRefreshFromSharedStateCatchesUpExpiredPhaseAndRecordsHistory() {
        let (vm, _, fakeAlert, store, history) = makeViewModel()
        vm.start()
        var expired = store.loadState()
        expired.endDate = Date().addingTimeInterval(-1)
        store.save(expired)

        vm.refreshFromSharedState()
        XCTAssertEqual(vm.state.phase, .shortBreak)
        XCTAssertEqual(history.totalCount, 1)
        XCTAssertEqual(fakeAlert.alertCount, 1)
    }

    func testReviewMilestoneRequestedAfterTenTotalSessions() {
        let (vm, _, _, store, history) = makeViewModel()
        for _ in 0..<9 {
            history.recordCompletedSession(duration: PomodoroPhase.work.duration)
        }
        vm.start()
        var expired = store.loadState()
        expired.endDate = Date().addingTimeInterval(-1)
        store.save(expired)

        vm.refreshFromSharedState()

        XCTAssertEqual(history.totalCount, 10)
        XCTAssertTrue(vm.pendingReviewRequest)
        XCTAssertTrue(store.loadHasRequestedReview())
    }

    func testReviewMilestoneNotRequestedBeforeReachingTenSessionsOrAStreak() {
        let (vm, _, _, store, history) = makeViewModel()
        vm.start()
        var expired = store.loadState()
        expired.endDate = Date().addingTimeInterval(-1)
        store.save(expired)

        vm.refreshFromSharedState()

        XCTAssertEqual(history.totalCount, 1)
        XCTAssertFalse(vm.pendingReviewRequest)
        XCTAssertFalse(store.loadHasRequestedReview())
    }
}
