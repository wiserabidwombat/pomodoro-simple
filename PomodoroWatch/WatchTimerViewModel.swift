// PomodoroWatch/WatchTimerViewModel.swift
import Foundation
import WatchKit

/// The watch runs its own TimerEngine against its own local storage
/// (UserDefaults.standard) — a paired Watch can't read the iPhone's App
/// Group — so every button works instantly, even with the phone out of
/// range. WatchConnectivityRelay keeps the two in step afterwards: the
/// phone sends its state, active profile, color, and today's progress; the
/// watch sends back its own timer changes and any Focus sessions it
/// finished, which the phone records in Stats.
@MainActor
final class WatchTimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published private(set) var accentColor: AccentColorOption
    @Published private(set) var profile: TimerProfile
    /// The profile's name, or nil when the phone has only one profile.
    @Published private(set) var profileLabel: String?
    /// Focus sessions finished today (from the phone, plus any finished here
    /// since it last reported), and the phone's daily goal (0 = none).
    @Published private(set) var todayCount: Int
    @Published private(set) var dailyGoal: Int

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let relay: WatchConnectivityRelay
    private let defaults: UserDefaults
    private var ticker: Timer?

    private static let profileLabelKey = "watch.profileLabel"
    private static let todayCountKey = "watch.todayCount"
    private static let todayCountDayKey = "watch.todayCountDay"
    private static let dailyGoalKey = "watch.dailyGoal"
    /// A phase that ended longer ago than this (the app was closed or
    /// asleep) is caught up silently: tapping the wrist minutes late,
    /// just because the app was opened, would be confusing.
    private static let hapticWindow: TimeInterval = 10

    init(relay: WatchConnectivityRelay, defaults: UserDefaults = .standard) {
        self.relay = relay
        self.defaults = defaults
        let store = PomodoroStateStore(defaults: defaults)
        self.store = store
        let loadedState = store.loadState()
        let loadedProfile = store.loadActiveProfile()
        self.engine = TimerEngine(state: loadedState, profile: loadedProfile)
        self.state = loadedState
        self.accentColor = store.loadAccentColor()
        self.profile = loadedProfile
        self.profileLabel = defaults.string(forKey: Self.profileLabelKey)
        self.dailyGoal = defaults.integer(forKey: Self.dailyGoalKey)
        self.todayCount = Self.loadTodayCount(defaults)

        relay.onReceivePayload = { [weak self] payload in
            Task { @MainActor in self?.adopt(payload) }
        }
    }

    // MARK: - Lifecycle

    /// The app came to the front: catch up a phase that ended while it was
    /// away, and tick once a second to notice the next one ending.
    func sceneDidBecomeActive() {
        refreshTodayCountForNewDay()
        catchUpIfNeeded()
        startTicker()
    }

    /// No point waking every second in the background. (Wrist-down Always On
    /// is .inactive, not .background, so the ticker keeps going there.)
    func sceneDidEnterBackground() {
        ticker?.invalidate()
        ticker = nil
    }

    // MARK: - Actions

    func start() {
        engine.start()
        persistAndSync()
    }

    func pause() {
        catchUpIfNeeded()
        engine.pause()
        persistAndSync()
    }

    func resume() {
        catchUpIfNeeded()
        engine.resume()
        persistAndSync()
    }

    func skip() {
        catchUpIfNeeded()
        engine.skip()
        persistAndSync()
    }

    func restart() {
        engine.reset()
        persistAndSync()
    }

    func focusElapsed() -> TimeInterval? {
        engine.focusElapsed()
    }

    var minimumFocusToCount: TimeInterval {
        engine.minimumFocusToCount
    }

    /// Same rule as the iPhone: past the halfway mark, a Focus session can
    /// end early and still count.
    func finishEarly() {
        catchUpIfNeeded()
        guard let completed = engine.finishEarly() else { return }
        report(completed)
        persistAndSync()
    }

    // MARK: - Sync

    /// What the phone sent. Its color, profile, and today's progress always
    /// win (it owns them). The timer state only wins if it's newer than the
    /// watch's own last change; if it's older (e.g. the watch was paused
    /// while out of range), the watch answers with its own state instead,
    /// so both end up on the newest change. Never echoed back otherwise.
    private func adopt(_ payload: WatchSyncPayload) {
        if let accentColor = payload.accentColor {
            self.accentColor = accentColor
            store.save(accentColor)
        }
        if let profile = payload.profile {
            self.profile = profile
            engine.updateProfile(profile)
            store.save(profiles: [profile])
            store.saveActiveProfileID(profile.id)
        }
        profileLabel = payload.profileLabel
        defaults.set(payload.profileLabel, forKey: Self.profileLabelKey)
        if let dailyGoal = payload.dailyGoal {
            self.dailyGoal = dailyGoal
            defaults.set(dailyGoal, forKey: Self.dailyGoalKey)
        }
        if let todayCount = payload.todayCount {
            saveTodayCount(todayCount)
        }

        // Equal stamps are the same change (or neither side has changed
        // anything since installing): taking the phone's copy is harmless.
        let localChangedAt = store.loadStateChangedAt()
        if payload.stateChangedAt >= localChangedAt {
            engine.reload(payload.state)
            state = payload.state
            store.save(payload.state)
            store.save(stateChangedAt: payload.stateChangedAt)
        } else if payload.stateChangedAt < localChangedAt {
            sendState()
        }
    }

    /// A change made here: save it, stamp it, and tell the phone.
    private func persistAndSync() {
        state = engine.state
        store.save(state)
        store.save(stateChangedAt: Date())
        sendState()
    }

    private func sendState() {
        relay.send(WatchSyncPayload(state: state, stateChangedAt: store.loadStateChangedAt()))
    }

    /// A Focus session finished on the watch: tell the phone so it lands in
    /// Stats. Queued by WatchConnectivity, so it arrives even if the phone
    /// is out of range right now. (If the phone noticed the same session end
    /// on its own, it counts it only once.)
    private func report(_ completed: CompletedPhase) {
        guard completed.phase == .work else { return }
        relay.sendCompletedSession(PendingCompletedSession(
            endedAt: completed.endedAt,
            duration: completed.duration,
            profileID: profile.id,
            profileName: profile.name
        ))
        if Calendar.current.isDateInToday(completed.endedAt) {
            // Shown right away; the phone's next update replaces it with
            // the real count.
            saveTodayCount(todayCount + 1)
        }
    }

    private func catchUpIfNeeded() {
        if let completed = engine.catchUpIfExpired() {
            report(completed)
            // A tap on the wrist when a phase ends with the app open. (With
            // the app closed, the iPhone's phase-end notification is
            // mirrored to the watch by the system instead.)
            if Date().timeIntervalSince(completed.endedAt) < Self.hapticWindow {
                WKInterfaceDevice.current().play(.notification)
            }
            persistAndSync()
        } else if state != engine.state {
            state = engine.state
        }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    // MARK: - Today's count

    private func saveTodayCount(_ count: Int) {
        todayCount = count
        defaults.set(count, forKey: Self.todayCountKey)
        defaults.set(Calendar.current.startOfDay(for: Date()), forKey: Self.todayCountDayKey)
    }

    private func refreshTodayCountForNewDay() {
        let current = Self.loadTodayCount(defaults)
        if current != todayCount { todayCount = current }
    }

    /// 0 once the saved count is from an earlier day.
    private static func loadTodayCount(_ defaults: UserDefaults) -> Int {
        guard let day = defaults.object(forKey: todayCountDayKey) as? Date,
              Calendar.current.isDateInToday(day)
        else { return 0 }
        return defaults.integer(forKey: todayCountKey)
    }
}
