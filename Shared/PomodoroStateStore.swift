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
        guard let data = defaults.data(forKey: stateKey),
              let decoded = try? JSONDecoder().decode(PomodoroState.self, from: data)
        else { return .idle }
        return decoded
    }

    func save(_ state: PomodoroState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
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
