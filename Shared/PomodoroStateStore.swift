// Shared/PomodoroStateStore.swift
import Foundation

/// A Focus session that ran out while something *other* than the app's
/// view model noticed it (a Lock Screen/StandBy/widget button, or dismissing
/// the phase-end notification). Those paths can't reach the app's SwiftData
/// store, so they queue it here in the App Group and the app imports it into
/// history the next time it catches up.
struct PendingCompletedSession: Codable, Equatable {
    let endedAt: Date
    let duration: TimeInterval
    var profileID: UUID? = nil
    var profileName: String? = nil
}

struct PomodoroStateStore {
    private let defaults: UserDefaults
    private let stateKey = "pomodoro.state"
    private let colorKey = "pomodoro.accentColor"
    /// Pre-profiles single set of durations; only read now, to seed the
    /// Classic profile for people updating from an older build.
    private let legacyDurationsKey = "pomodoro.durations"
    private let profilesKey = "pomodoro.profiles"
    private let activeProfileIDKey = "pomodoro.activeProfileID"
    private let silenceDuringFocusKey = "pomodoro.silenceDuringFocus"
    private let soundEnabledKey = "pomodoro.soundEnabled"
    private let keepScreenAwakeKey = "pomodoro.keepScreenAwake"
    private let skipCountsPastHalfwayKey = "pomodoro.skipCountsPastHalfway"
    private let dailyGoalKey = "pomodoro.dailyGoal"
    private let chimeKey = "pomodoro.chime"
    private let todayCountKey = "pomodoro.todayCount"
    private let todayCountDateKey = "pomodoro.todayCountDate"
    private let hasRequestedReviewKey = "pomodoro.hasRequestedReview"
    private let pendingSessionsKey = "pomodoro.pendingCompletedSessions"
    /// Intents run in the app's own process (LiveActivityIntent), possibly
    /// off the main thread, while the app's ticker drains on main — so the
    /// queue's read-modify-write needs to be serialized.
    private static let pendingSessionsLock = NSLock()

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func loadState() -> PomodoroState {
        // Force a fresh read from disk rather than this process's cached
        // copy of the key — without this, a widget extension process that
        // already read `stateKey` once can keep seeing a stale value even
        // after the app process (a different process) has since written a
        // newer one to the same App Group suite.
        defaults.synchronize()
        guard let data = defaults.data(forKey: stateKey),
              let decoded = try? JSONDecoder().decode(PomodoroState.self, from: data)
        else { return .idle }
        return decoded
    }

    func save(_ state: PomodoroState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
        defaults.synchronize()
    }

    func loadAccentColor() -> AccentColorOption {
        if let data = defaults.data(forKey: colorKey),
           let decoded = try? JSONDecoder().decode(AccentColorOption.self, from: data) {
            return decoded
        }
        // Migrate a value saved by the old String-rawValue-backed enum,
        // before AccentColorOption grew a custom-RGB case and switched to
        // JSON storage.
        if let raw = defaults.string(forKey: colorKey),
           let preset = AccentColorOption.Preset(rawValue: raw) {
            return .preset(preset)
        }
        return .white
    }

    func save(_ color: AccentColorOption) {
        guard let data = try? JSONEncoder().encode(color) else { return }
        defaults.set(data, forKey: colorKey)
    }

    // MARK: - Timer profiles

    /// Never empty. Until a list has been saved (a fresh install, or an
    /// update from before profiles existed) this returns Classic — carrying
    /// over whatever durations were set in Settings back then — plus a
    /// Deep Work example.
    func loadProfiles() -> [TimerProfile] {
        defaults.synchronize()
        if let data = defaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([TimerProfile].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        var classic = TimerProfile.classic
        classic.durations = loadLegacyDurations() ?? .default
        return [classic, .deepWork]
    }

    func save(profiles: [TimerProfile]) {
        guard !profiles.isEmpty, let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: profilesKey)
        defaults.synchronize()
    }

    /// Falls back to the first profile if the saved id no longer exists
    /// (e.g. that profile was deleted).
    func loadActiveProfile() -> TimerProfile {
        let profiles = loadProfiles()
        let activeID = defaults.string(forKey: activeProfileIDKey).flatMap(UUID.init(uuidString:))
        return profiles.first(where: { $0.id == activeID }) ?? profiles[0]
    }

    func saveActiveProfileID(_ id: UUID) {
        defaults.set(id.uuidString, forKey: activeProfileIDKey)
        defaults.synchronize()
    }

    /// The active profile's name, for showing next to the phase on the Lock
    /// Screen and widgets — but only once there's more than one profile to
    /// tell apart; "Classic · Focus" alone would just be noise.
    func loadActiveProfileLabel() -> String? {
        loadProfiles().count > 1 ? loadActiveProfile().name : nil
    }

    func loadDurations() -> PomodoroDurations {
        loadActiveProfile().durations
    }

    private func loadLegacyDurations() -> PomodoroDurations? {
        guard let data = defaults.data(forKey: legacyDurationsKey) else { return nil }
        return try? JSONDecoder().decode(PomodoroDurations.self, from: data)
    }

    func loadSilenceDuringFocus() -> Bool {
        defaults.bool(forKey: silenceDuringFocusKey)
    }

    /// Off by default — it costs battery, so it's opt-in.
    func loadKeepScreenAwake() -> Bool {
        defaults.bool(forKey: keepScreenAwakeKey)
    }

    func save(keepScreenAwake: Bool) {
        defaults.set(keepScreenAwake, forKey: keepScreenAwakeKey)
    }

    /// Whether Skip from outside the app counts a Focus session that's past
    /// halfway (see TimerEngine.skipFromOutsideApp). On by default; like
    /// sound, a missing key has to read as true.
    func loadSkipCountsPastHalfway() -> Bool {
        guard defaults.object(forKey: skipCountsPastHalfwayKey) != nil else { return true }
        return defaults.bool(forKey: skipCountsPastHalfwayKey)
    }

    func save(skipCountsPastHalfway: Bool) {
        defaults.set(skipCountsPastHalfway, forKey: skipCountsPastHalfwayKey)
    }

    static let dailyGoalRange = 0...16

    /// Focus sessions to aim for each day, across all profiles. 0 = no goal
    /// (the default). In the App Group so the widget can show progress.
    func loadDailyGoal() -> Int {
        clampDailyGoal(defaults.integer(forKey: dailyGoalKey))
    }

    func save(dailyGoal: Int) {
        defaults.set(clampDailyGoal(dailyGoal), forKey: dailyGoalKey)
    }

    private func clampDailyGoal(_ goal: Int) -> Int {
        min(max(goal, Self.dailyGoalRange.lowerBound), Self.dailyGoalRange.upperBound)
    }

    func save(silenceDuringFocus: Bool) {
        defaults.set(silenceDuringFocus, forKey: silenceDuringFocusKey)
    }

    /// Defaults to true (sound on) — bool(forKey:) alone can't distinguish
    /// "never set" from "explicitly set to false", both of which return false.
    func loadSoundEnabled() -> Bool {
        guard defaults.object(forKey: soundEnabledKey) != nil else { return true }
        return defaults.bool(forKey: soundEnabledKey)
    }

    func save(soundEnabled: Bool) {
        defaults.set(soundEnabled, forKey: soundEnabledKey)
    }

    func loadChime() -> ChimeOption {
        let raw = defaults.object(forKey: chimeKey) as? UInt32
        return raw.flatMap(ChimeOption.init(rawValue:)) ?? .default
    }

    func save(_ chime: ChimeOption) {
        defaults.set(chime.rawValue, forKey: chimeKey)
    }

    /// A lightweight mirror of HistoryStore.todayCount, kept in sync by the
    /// app each time a Focus session completes. The widget extension can't
    /// read the app's SwiftData store directly (it isn't in the App Group
    /// container), so this is the channel it reads "today's count" from
    /// instead. Day-tagged so a stale cache from a previous day reads back
    /// as 0 rather than showing yesterday's number after midnight.
    func incrementCachedTodayCount(calendar: Calendar = .current, now: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        let count = loadCachedTodayCount(calendar: calendar, now: now)
        defaults.set(count + 1, forKey: todayCountKey)
        defaults.set(today, forKey: todayCountDateKey)
    }

    func loadCachedTodayCount(calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard let cachedDay = defaults.object(forKey: todayCountDateKey) as? Date,
              calendar.isDate(cachedDay, inSameDayAs: now)
        else { return 0 }
        return defaults.integer(forKey: todayCountKey)
    }

    func enqueueCompletedSession(_ session: PendingCompletedSession) {
        Self.pendingSessionsLock.lock()
        defer { Self.pendingSessionsLock.unlock() }
        var queue = readPendingSessions()
        queue.append(session)
        if let data = try? JSONEncoder().encode(queue) {
            defaults.set(data, forKey: pendingSessionsKey)
        }
    }

    /// Returns everything queued so far and empties the queue.
    func drainPendingCompletedSessions() -> [PendingCompletedSession] {
        Self.pendingSessionsLock.lock()
        defer { Self.pendingSessionsLock.unlock() }
        let queue = readPendingSessions()
        if !queue.isEmpty {
            defaults.removeObject(forKey: pendingSessionsKey)
        }
        return queue
    }

    private func readPendingSessions() -> [PendingCompletedSession] {
        guard let data = defaults.data(forKey: pendingSessionsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingCompletedSession].self, from: data)) ?? []
    }

    /// Guards against ever asking for a review more than once — SwiftUI's
    /// requestReview action is a hint the system silently throttles on its
    /// own (at most ~3 times per year, and never if already rated), but
    /// calling it repeatedly at every milestone regardless is still poor
    /// practice, so this makes it fire exactly once, the first time a
    /// milestone is reached.
    func loadHasRequestedReview() -> Bool {
        defaults.bool(forKey: hasRequestedReviewKey)
    }

    func markReviewRequested() {
        defaults.set(true, forKey: hasRequestedReviewKey)
    }
}
