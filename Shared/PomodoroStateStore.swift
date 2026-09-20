// Shared/PomodoroStateStore.swift
import Foundation

struct PomodoroStateStore {
    private let defaults: UserDefaults
    private let stateKey = "pomodoro.state"
    private let colorKey = "pomodoro.accentColor"
    private let durationsKey = "pomodoro.durations"
    private let silenceDuringFocusKey = "pomodoro.silenceDuringFocus"
    private let soundEnabledKey = "pomodoro.soundEnabled"
    private let chimeKey = "pomodoro.chime"
    private let todayCountKey = "pomodoro.todayCount"
    private let todayCountDateKey = "pomodoro.todayCountDate"

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

    func loadDurations() -> PomodoroDurations {
        defaults.synchronize()
        guard let data = defaults.data(forKey: durationsKey),
              let decoded = try? JSONDecoder().decode(PomodoroDurations.self, from: data)
        else { return .default }
        return decoded
    }

    func save(_ durations: PomodoroDurations) {
        guard let data = try? JSONEncoder().encode(durations) else { return }
        defaults.set(data, forKey: durationsKey)
        defaults.synchronize()
    }

    func loadSilenceDuringFocus() -> Bool {
        defaults.bool(forKey: silenceDuringFocusKey)
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
}
