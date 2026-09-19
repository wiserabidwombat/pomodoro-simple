// Shared/PomodoroStateStore.swift
import Foundation

struct PomodoroStateStore {
    private let defaults: UserDefaults
    private let stateKey = "pomodoro.state"
    private let colorKey = "pomodoro.accentColor"

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
        guard let raw = defaults.string(forKey: colorKey),
              let option = AccentColorOption(rawValue: raw)
        else { return .white }
        return option
    }

    func save(_ color: AccentColorOption) {
        defaults.set(color.rawValue, forKey: colorKey)
    }
}
