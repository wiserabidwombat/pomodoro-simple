// Pomodoro/Timer/TimerViewModel.swift
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published var accentColor: AccentColorOption {
        didSet { store.save(accentColor) }
    }

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let notifications: NotificationScheduler
    private let historyStore: HistoryStore
    private let liveActivity: LiveActivityControlling
    private let alerting: PhaseChangeAlerting
    private var ticker: Timer?

    init(
        store: PomodoroStateStore = PomodoroStateStore(),
        notifications: NotificationScheduler = NotificationScheduler(),
        historyStore: HistoryStore,
        liveActivity: LiveActivityControlling,
        alerting: PhaseChangeAlerting
    ) {
        self.store = store
        self.notifications = notifications
        self.historyStore = historyStore
        self.liveActivity = liveActivity
        self.alerting = alerting
        let loaded = store.loadState()
        self.engine = TimerEngine(state: loaded)
        self.state = loaded
        self.accentColor = store.loadAccentColor()
    }

    func start() {
        engine.start()
        persistAndPush()
        liveActivity.start(state: engine.state, accentColor: accentColor)
        startTicker()
    }

    func pause() {
        engine.pause()
        persistAndPush()
    }

    func resume() {
        engine.resume()
        persistAndPush()
    }

    func skip() {
        engine.skip()
        persistAndPush()
    }

    /// Call when the app becomes active: the widget extension may have
    /// mutated the shared store while this process was backgrounded, so the
    /// in-memory engine must reload before it can safely catch up.
    func refreshFromSharedState() {
        engine.reload(store.loadState())
        catchUpIfNeeded()
    }

    private func catchUpIfNeeded() {
        let phaseBefore = engine.state.phase
        if engine.catchUpIfExpired() {
            historyStore.recordCompletedSession(duration: PomodoroPhase.work.duration)
        }
        if engine.state.phase != phaseBefore {
            alerting.alertPhaseChange()
        }
        persistAndPush()
    }

    private func persistAndPush() {
        state = engine.state
        store.save(state)
        if state.sessionActive, state.pausedAt == nil {
            notifications.schedulePhaseEnd(phase: state.phase, endDate: state.endDate)
        } else {
            notifications.cancelPhaseEnd()
        }
        liveActivity.update(state: state, accentColor: accentColor)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
    }
}
