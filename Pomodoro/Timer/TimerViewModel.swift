// Pomodoro/Timer/TimerViewModel.swift
import AppIntents
import Foundation
import os

private let viewModelLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "TimerViewModel")

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    /// The user's own accent color, as edited in Settings. Draw with
    /// `displayAccent`, which a holiday theme can override.
    @Published var accentColor: AccentColorOption {
        didSet {
            store.save(accentColor)
            scheduleAppearancePush()
        }
    }
    /// Settings → Holiday Theme.
    @Published var themeSetting: ThemeSetting {
        didSet {
            store.save(themeSetting: themeSetting)
            refreshActiveTheme()
        }
    }
    /// The theme showing right now (nil = normal look). Recomputed when the
    /// setting changes, when the app comes to the foreground, and at midnight.
    @Published private(set) var activeTheme: HolidayTheme?
    /// Goes up by one each time a Focus session finishes while the app is
    /// open and a theme is showing; the Timer screen plays a burst on change.
    @Published private(set) var celebrationCount = 0

    /// The color everything in the app should draw with.
    var displayAccent: AccentColorOption { activeTheme?.accent ?? accentColor }
    /// Saved timer setups, in the user's order. Never empty.
    @Published private(set) var profiles: [TimerProfile]
    /// The one new sessions run with. Only switchable while idle.
    @Published private(set) var activeProfile: TimerProfile
    @Published var silenceDuringFocus: Bool {
        didSet { store.save(silenceDuringFocus: silenceDuringFocus) }
    }
    /// Stop the phone from auto-locking while a session is running and the
    /// Timer screen is showing (see TimerView.updateIdleTimer()).
    @Published var keepScreenAwake: Bool {
        didSet { store.save(keepScreenAwake: keepScreenAwake) }
    }
    /// Skip on the Lock Screen/StandBy/widgets counts Focus past halfway.
    @Published var skipCountsPastHalfway: Bool {
        didSet { store.save(skipCountsPastHalfway: skipCountsPastHalfway) }
    }
    /// Focus sessions to aim for each day (all profiles); 0 = off.
    @Published var dailyGoal: Int {
        didSet {
            store.save(dailyGoal: dailyGoal)
            reloadIdlePomodoroWidget()
        }
    }
    /// Completed Focus sessions today, for the daily-goal progress. Kept
    /// here (rather than queried by the view) so the Timer screen doesn't
    /// hit SwiftData on every render.
    @Published private(set) var todayCount: Int
    private var todayCountDay = Date()
    @Published var soundEnabled: Bool {
        didSet {
            store.save(soundEnabled: soundEnabled)
            // Re-schedule the already-pending phase-end notification so it
            // picks up the new setting now, not only from the next phase.
            // (Notification only — saving state from a settings toggle
            // could clobber a change another process just made.)
            if state.sessionActive, state.pausedAt == nil {
                notifications.schedulePhaseEnd(
                    phase: state.phase,
                    endDate: state.endDate,
                    playSound: soundEnabled,
                    profileLabel: store.loadActiveProfileLabel()
                )
            }
        }
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
        let loadedActive = store.loadActiveProfile()
        self.engine = TimerEngine(state: loaded, profile: loadedActive)
        self.state = loaded
        self.accentColor = store.loadAccentColor()
        self.profiles = store.loadProfiles()
        self.activeProfile = loadedActive
        self.silenceDuringFocus = store.loadSilenceDuringFocus()
        self.keepScreenAwake = store.loadKeepScreenAwake()
        self.skipCountsPastHalfway = store.loadSkipCountsPastHalfway()
        self.dailyGoal = store.loadDailyGoal()
        self.todayCount = historyStore.todayCount
        self.soundEnabled = store.loadSoundEnabled()
        self.chime = store.loadChime()
        let loadedTheme = store.loadThemeSetting()
        self.themeSetting = loadedTheme
        self.activeTheme = loadedTheme.activeTheme()
    }

    func start() {
        engine.start()
        persistAndPush()
    }

    // MARK: - Timer profiles

    /// Switching is only allowed between sessions, so a running cycle never
    /// changes shape underneath you.
    func selectProfile(id: UUID) {
        guard !state.sessionActive, let profile = profiles.first(where: { $0.id == id }) else { return }
        activeProfile = profile
        store.saveActiveProfileID(profile.id)
        engine.updateProfile(profile)
        reloadIdlePomodoroWidget()
    }

    /// Adds a new profile, or saves edits to an existing one. Editing the
    /// active profile mid-session only affects the next phase, the same as
    /// changing durations always has.
    func saveProfile(_ profile: TimerProfile) {
        var updated = profiles
        if let index = updated.firstIndex(where: { $0.id == profile.id }) {
            updated[index] = profile
        } else {
            updated.append(profile)
        }
        profiles = updated
        store.save(profiles: updated)
        if profile.id == activeProfile.id {
            activeProfile = profile
            engine.updateProfile(profile)
        }
        reloadIdlePomodoroWidget()
        // So Siri recognizes new and renamed profiles in "Start … with …".
        PomodoroAppShortcuts.updateAppShortcutParameters()
    }

    /// The last remaining profile can't go, and neither can the one a
    /// running session is using.
    func canDeleteProfile(_ profile: TimerProfile) -> Bool {
        profiles.count > 1 && !(profile.id == activeProfile.id && state.sessionActive)
    }

    /// Past sessions keep their profile tag (and stored name), so deleting
    /// a profile never removes anything from Stats.
    func deleteProfile(id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }), canDeleteProfile(profile) else { return }
        let remaining = profiles.filter { $0.id != id }
        profiles = remaining
        store.save(profiles: remaining)
        if id == activeProfile.id {
            let next = remaining[0]
            activeProfile = next
            store.saveActiveProfileID(next.id)
            engine.updateProfile(next)
        }
        reloadIdlePomodoroWidget()
        PomodoroAppShortcuts.updateAppShortcutParameters()
    }

    // Pause/Resume/Skip first sync with the shared store (and catch up a
    // phase that already ran out), exactly like the Lock Screen intents do,
    // so a tap in the app can never act on an in-memory state that's up to
    // a tick stale — e.g. Skip on a phase that just expired would otherwise
    // skip the phase *after* it too.
    func pause() {
        catchUpIfNeeded()
        engine.pause()
        persistAndPush()
    }

    func resume() {
        catchUpIfNeeded()
        engine.resume()
        persistAndPush()
    }

    func skip() {
        catchUpIfNeeded()
        engine.skip()
        persistAndPush()
    }

    /// Focus time done so far in the current Focus phase (nil otherwise),
    /// for the "end Focus early?" prompt.
    func focusElapsed() -> TimeInterval? {
        engine.focusElapsed()
    }

    var minimumFocusToCount: TimeInterval {
        engine.minimumFocusToCount
    }

    /// "Finish & Count It": ends Focus now and records it in Stats with the
    /// time actually focused, instead of throwing it away like Skip does.
    /// Goes through the same queue as every other completion, so it's
    /// tagged with the active profile and bumps the widget's Today count.
    /// No chime — like Skip, it's a deliberate tap, not a timer running out.
    func finishEarly() {
        catchUpIfNeeded()
        guard let completed = engine.finishEarly() else { return }
        recordNaturalCompletion(completed, store: store)
        celebrateIfThemed(completed)
        importPendingSessions()
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
        refreshActiveTheme()
        refreshFromSharedState()
        saveWeekForWidgets()
        startTicker()
    }

    // MARK: - Recent activity (iPad panel, large widgets)

    /// What the iPad's side panel shows next to the timer.
    struct RecentActivity: Equatable {
        var lastSevenDays: [DailyCount] = []
        var todayFocusSeconds: TimeInterval = 0
    }

    /// Read from history on demand — the panel calls this when it appears
    /// and whenever `historyRevision` changes, never from a ticking body.
    func recentActivity(calendar: Calendar = .current, now: Date = Date()) -> RecentActivity {
        let sessions = historyStore.sessions()
        let lastSevenDays = StatsSnapshot.lastSevenDays(
            StatsSnapshot.countByDay(sessions.map(\.date), calendar: calendar),
            calendar: calendar,
            now: now
        )
        let todayFocus = sessions
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .reduce(0) { $0 + $1.durationSeconds }
        return RecentActivity(lastSevenDays: lastSevenDays, todayFocusSeconds: todayFocus)
    }

    /// Copies the last 7 days' counts into the App Group for the large
    /// widgets, which can't read SwiftData themselves.
    private func saveWeekForWidgets() {
        guard historyStore.isPersistent else { return }
        store.save(recentDailyCounts: historyStore.lastSevenDaysCounts().map(\.count))
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
        // Siri, a Shortcut, or the Action Button can switch the active
        // profile from outside the app (StartProfileIntent); pick that up
        // too, so the Timer screen's menu, dots, and Help match.
        let storedProfile = store.loadActiveProfile()
        if storedProfile != activeProfile {
            activeProfile = storedProfile
            engine.updateProfile(storedProfile)
        }
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
            celebrateIfThemed(completed)
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
        // Runs every tick, so it's also where "today" rolls over at
        // midnight for an app left open overnight.
        if !Calendar.current.isDate(todayCountDay, inSameDayAs: Date()) {
            refreshActiveTheme()
            refreshTodayCount()
        }
        // With history in memory only, leave sessions queued in the App
        // Group so a later launch with a working database imports them.
        guard historyStore.isPersistent else { return }
        let pending = store.drainPendingCompletedSessions()
        guard !pending.isEmpty else { return }
        historyStore.recordCompletedSessions(pending)
        historyRevision += 1
        refreshTodayCount()
        checkReviewMilestone()
    }

    private func refreshTodayCount() {
        todayCountDay = Date()
        saveWeekForWidgets()
        let count = historyStore.todayCount
        // Only publish a real change (see catchUpIfNeeded's note on why).
        if count != todayCount {
            todayCount = count
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
            liveActivity.start(state: state, accentColor: displayAccent)
        } else {
            liveActivity.update(state: state, accentColor: displayAccent)
        }
        reloadIdlePomodoroWidget()
    }

    // MARK: - Holiday theme

    /// Picks up a theme change (the setting, or the date crossing into a new
    /// season) and pushes the new color to the Live Activity and widgets.
    func refreshActiveTheme(now: Date = Date()) {
        let theme = themeSetting.activeTheme(on: now)
        guard theme != activeTheme else { return }
        activeTheme = theme
        scheduleAppearancePush()
    }

    private func celebrateIfThemed(_ completed: CompletedPhase) {
        guard completed.phase == .work, activeTheme != nil else { return }
        celebrationCount += 1
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
                self.liveActivity.update(state: self.state, accentColor: self.displayAccent)
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
