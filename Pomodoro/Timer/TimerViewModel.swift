// Pomodoro/Timer/TimerViewModel.swift
import Foundation
import os

private let viewModelLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "TimerViewModel")

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published var accentColor: AccentColorOption {
        didSet {
            store.save(accentColor)
            scheduleAppearancePush()
        }
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
    /// Bumped whenever new sessions land in history, so the Stats screen
    /// knows to recompute instead of re-querying on every render.
    @Published private(set) var historyRevision = 0

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let notifications: NotificationScheduler
    private let historyStore: HistoryStore
    private let liveActivity: LiveActivityControlling
    private let alerting: PhaseChangeAlerting
    private var ticker: Timer?
    private var appearancePushTask: Task<Void, Never>?

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
        engine.reset()
        state = engine.state
        persistPomodoroState(state, store: store, notifications: notifications)
        liveActivity.end()
        reloadIdlePomodoroWidget()
    }

    /// Call whenever the scene becomes active (including the very first
    /// time, on a cold launch): reloads what other processes may have
    /// changed and keeps the ticker running for as long as the app is in
    /// the foreground. The ticker used to be started only by the Start
    /// button, so a relaunch mid-session had no ticker at all — a phase
    /// could run out on screen without ever advancing, and a Start from
    /// Siri/Shortcuts while the app was open was never picked up.
    func sceneDidBecomeActive() {
        refreshFromSharedState()
        startTicker()
    }

    /// No point waking every second while backgrounded; the next
    /// sceneDidBecomeActive() reloads and catches up anything missed.
    func sceneDidEnterBackground() {
        ticker?.invalidate()
        ticker = nil
    }

    /// The widget extension may have mutated the shared store while this
    /// process was backgrounded, so the in-memory engine must reload
    /// before it can safely catch up.
    func refreshFromSharedState() {
        // Unconditionally push here (not just when a phase auto-completed):
        // this is also the app's one reliable path for correcting the Live
        // Activity's visible content after an external pause/resume/skip
        // (e.g. from the Lock Screen), since the widget extension's own
        // update path is unreliable on this SDK — see
        // PomodoroLiveActivityIntents.swift's diagnostic marker.
        catchUpIfNeeded(forcePush: true)
    }

    private func catchUpIfNeeded(forcePush: Bool = false) {
        // Reload before doing anything else, every tick — not just on
        // foreground transitions. A Lock Screen/StandBy button tap runs in
        // its own separate TimerEngine instance backed only by the shared
        // store (see PomodoroLiveActivityIntents.swift); this process's own
        // long-lived engine has no way to learn about that change except by
        // re-reading the store. Without this, the ticker (which keeps
        // firing in the background and resumes the instant the app comes
        // back from being suspended) could race the scenePhase-triggered
        // reload above and stomp an externally-applied change with its own
        // stale, independently-computed catch-up — e.g. Skip on StandBy
        // advancing to Break, then reopening the app immediately reverting
        // to Focus because the ticker caught up a still-Focus in-memory
        // copy a beat before/after the real reload landed.
        let beforeReload = engine.state
        engine.reload(store.loadState())
        let reloaded = engine.state
        if beforeReload.phase != reloaded.phase || beforeReload.completedWorkCycles != reloaded.completedWorkCycles {
            viewModelLogger.log("""
            catchUpIfNeeded(forcePush=\(forcePush, privacy: .public)) reload changed in-memory state: \
            \(beforeReload.phase.rawValue, privacy: .public)(cycles=\(beforeReload.completedWorkCycles, privacy: .public)) -> \
            \(reloaded.phase.rawValue, privacy: .public)(cycles=\(reloaded.completedWorkCycles, privacy: .public))
            """)
        }
        let completed = engine.catchUpIfExpired()
        let advanced = completed != nil
        if advanced {
            let afterCatchUp = engine.state
            viewModelLogger.log("""
            catchUpIfNeeded(forcePush=\(forcePush, privacy: .public)) catchUpIfExpired advanced to \
            \(afterCatchUp.phase.rawValue, privacy: .public)(cycles=\(afterCatchUp.completedWorkCycles, privacy: .public))
            """)
            alerting.alertPhaseChange()
        }
        if let completed {
            recordNaturalCompletion(completed, store: store)
        }
        importPendingSessions()
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
            //
            // Only publish an actual change: assigning an identical value
            // to an @Published property still fires objectWillChange,
            // which re-rendered every screen observing this view model
            // (Stats included, with all its SwiftData queries) once a second.
            if state != engine.state {
                state = engine.state
            }
        }
    }

    /// Moves Focus sessions queued in the App Group (by this ticker, or by
    /// a Lock Screen/widget intent or notification dismissal) into SwiftData.
    private func importPendingSessions() {
        let pending = store.drainPendingCompletedSessions()
        guard !pending.isEmpty else { return }
        historyStore.recordCompletedSessions(pending)
        historyRevision += 1
        checkReviewMilestone()
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

    /// Prefers update() to avoid tearing down and recreating the Lock
    /// Screen card on every tick, but self-heals by requesting a fresh
    /// Activity whenever the current one has died (the OS-enforced ~8-hour
    /// lifetime cap, or any other reason) — this is what lets the app
    /// recover on its own the moment it gets any execution window (a
    /// foreground, or a Lock Screen button tap), instead of leaving the
    /// Lock Screen stuck until the person happens to hit Restart.
    private func persistAndPush() {
        state = engine.state
        persistPomodoroState(state, store: store, notifications: notifications)
        if state.sessionActive && liveActivity.needsRestart {
            liveActivity.start(state: state, accentColor: accentColor)
        } else {
            liveActivity.update(state: state, accentColor: accentColor)
        }
        reloadIdlePomodoroWidget()
    }

    /// The Live Activity and idle widget only redraw when told to, so a new
    /// accent color used to show up there only after the next
    /// pause/resume/skip. Debounced because the custom ColorPicker fires on
    /// every drag step, and Live Activity updates are budgeted by the system.
    private func scheduleAppearancePush() {
        appearancePushTask?.cancel()
        appearancePushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            if self.state.sessionActive {
                self.liveActivity.update(state: self.state, accentColor: self.accentColor)
            }
            reloadIdlePomodoroWidget()
        }
    }

    /// One ticker beat: pick up external changes and notice a phase
    /// running out. Internal (not private) so tests can drive it directly.
    func tick() {
        catchUpIfNeeded()
    }

    private func startTicker() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Lets the system coalesce wakeups; a phase ending up to 0.1s late
        // is invisible next to the 1s tick itself.
        timer.tolerance = 0.1
        // .common (not the default mode scheduledTimer uses) so the ticker
        // keeps firing while a List/ScrollView is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }
}
