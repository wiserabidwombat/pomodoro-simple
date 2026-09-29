// PomodoroTests/TimerViewModelTests.swift
import Combine
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
        let vm = TimerViewModel(store: store, notifications: NotificationScheduler(), historyStore: history, liveActivity: fakeActivity, alerting: fakeAlert)
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

    func testExpiredBreakIsPersistedOnceAndAlertsOnce() {
        // Regression: a break running out in the foreground used to be
        // re-advanced (and re-alerted) on every tick, because the advance
        // was never written back to the shared store.
        let (vm, _, fakeAlert, store, history) = makeViewModel()
        vm.start()
        vm.skip() // -> shortBreak
        var expired = store.loadState()
        expired.endDate = Date().addingTimeInterval(-1)
        store.save(expired)

        vm.tick()
        let afterFirstTick = store.loadState()
        XCTAssertEqual(afterFirstTick.phase, .work)
        XCTAssertEqual(vm.state, afterFirstTick)

        vm.tick()
        vm.tick()
        XCTAssertEqual(store.loadState(), afterFirstTick)
        XCTAssertEqual(fakeAlert.alertCount, 1)
        XCTAssertEqual(history.totalCount, 0) // a break isn't a Focus session
    }

    func testTickImportsFocusSessionsCompletedOutsideTheApp() {
        // E.g. "Continue" tapped on the Lock Screen, or the phase-end
        // notification dismissed: those intents queue the session in the
        // App Group; the app must pull it into history.
        let (vm, _, _, store, history) = makeViewModel()
        let endedAt = Date().addingTimeInterval(-60)
        store.enqueueCompletedSession(PendingCompletedSession(endedAt: endedAt, duration: 1500))

        vm.tick()

        XCTAssertEqual(history.totalCount, 1)
        XCTAssertEqual(history.totalFocusSeconds, 1500)
        XCTAssertEqual(vm.historyRevision, 1)
        XCTAssertEqual(store.drainPendingCompletedSessions(), [])
    }

    func testTickDoesNotPublishWhenNothingChanged() {
        // Every observing screen re-renders on objectWillChange, so an idle
        // or mid-countdown tick must not fire it.
        let (vm, _, _, _, _) = makeViewModel()
        vm.start()
        var changeCount = 0
        let subscription = vm.objectWillChange.sink { changeCount += 1 }
        vm.tick()
        vm.tick()
        XCTAssertEqual(changeCount, 0)
        subscription.cancel()
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
