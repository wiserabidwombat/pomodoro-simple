// Pomodoro/Timer/TimerViewModel.swift
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published var accentColor: AccentColorOption {
        didSet { store.save(accentColor) }
    }
    @Published var durations: PomodoroDurations {
        didSet {
            store.save(durations)
            engine.updateDurations(durations)
        }
    }
    @Published var silenceDuringFocus: Bool {
        didSet { store.save(silenceDuringFocus: silenceDuringFocus) }
    }
    @Published var soundEnabled: Bool {
        didSet { store.save(soundEnabled: soundEnabled) }
    }
    @Published var chime: ChimeOption {
        didSet { store.save(chime) }
    }
    /// One-shot signal the view observes to actually invoke SwiftUI's
    /// requestReview environment action — the ViewModel has no access to
    /// that itself. Set true right as a milestone is reached, and the view
    /// resets it back to false after acting on it.
    @Published var pendingReviewRequest = false

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let notifications: NotificationScheduler
    private let historyStore: HistoryStore
    private let liveActivity: LiveActivityControlling
    private let alerting: PhaseChangeAlerting
    private let watchSync: WatchSyncSending
    private var ticker: Timer?

    init(
        store: PomodoroStateStore = PomodoroStateStore(),
        notifications: NotificationScheduler = NotificationScheduler(),
        historyStore: HistoryStore,
        liveActivity: LiveActivityControlling,
        alerting: PhaseChangeAlerting,
        watchSync: WatchSyncSending
    ) {
        self.store = store
        self.notifications = notifications
        self.historyStore = historyStore
        self.liveActivity = liveActivity
        self.alerting = alerting
        self.watchSync = watchSync
        let loaded = store.loadState()
        let loadedDurations = store.loadDurations()
        self.engine = TimerEngine(state: loaded, durations: loadedDurations)
        self.state = loaded
        self.accentColor = store.loadAccentColor()
        self.durations = loadedDurations
        self.silenceDuringFocus = store.loadSilenceDuringFocus()
        self.soundEnabled = store.loadSoundEnabled()
        self.chime = store.loadChime()
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

    /// Stops the session entirely and returns to idle (Work phase, cycle
    /// count reset to 0) — ends the Live Activity rather than updating it,
    /// since there's no longer a session to show.
    func restart() {
        ticker?.invalidate()
        ticker = nil
        engine.reset()
        state = engine.state
        persistPomodoroState(state, store: store, notifications: notifications)
        liveActivity.end()
        reloadIdlePomodoroWidget()
        watchSync.send(state: state, accentColor: accentColor, durations: durations)
    }

    /// Call when the app becomes active: the widget extension may have
    /// mutated the shared store while this process was backgrounded, so the
    /// in-memory engine must reload before it can safely catch up.
    func refreshFromSharedState() {
        engine.reload(store.loadState())
        // Unconditionally push here (not just when a phase auto-completed):
        // this is also the app's one reliable path for correcting the Live
        // Activity's visible content after an external pause/resume/skip
        // (e.g. from the Lock Screen), since the widget extension's own
        // update path is unreliable on this SDK — see
        // PomodoroLiveActivityIntents.swift's diagnostic marker. Runs once
        // per foreground transition, not every tick, so this is cheap.
        catchUpIfNeeded(forcePush: true)
    }

    private func catchUpIfNeeded(forcePush: Bool = false) {
        let phaseBefore = engine.state.phase
        let advanced = engine.catchUpIfExpired()
        if advanced {
            historyStore.recordCompletedSession(duration: PomodoroPhase.work.duration)
            store.incrementCachedTodayCount()
            checkReviewMilestone()
        }
        if engine.state.phase != phaseBefore {
            alerting.alertPhaseChange()
        }
        if advanced || forcePush {
            persistAndPush()
        } else {
            // Still reflect the reloaded engine state in the UI, but skip
            // the heavier save/notify/live-activity work. The ticker fires
            // every second purely to detect a phase naturally expiring;
            // doing the full push every tick even while paused/idle is
            // wasteful (and previously fought Text(timerInterval:pauseTime:)'s
            // own clock before that view was replaced with a manually
            // formatted freeze).
            state = engine.state
        }
    }

    /// Fires at most once ever, right after a Focus session completes
    /// naturally — a positive moment, per Apple's own guidance on when
    /// asking for a review lands well rather than reading as an interruption.
    private func checkReviewMilestone() {
        guard !store.loadHasRequestedReview() else { return }
        let reachedMilestone = historyStore.totalCount >= 10 || historyStore.currentStreak() >= 3
        guard reachedMilestone else { return }
        store.markReviewRequested()
        pendingReviewRequest = true
    }

    private func persistAndPush() {
        state = engine.state
        persistPomodoroState(state, store: store, notifications: notifications)
        liveActivity.update(state: state, accentColor: accentColor)
        reloadIdlePomodoroWidget()
        watchSync.send(state: state, accentColor: accentColor, durations: durations)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
    }
}
