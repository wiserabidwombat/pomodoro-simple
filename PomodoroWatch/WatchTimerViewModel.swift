// PomodoroWatch/WatchTimerViewModel.swift
import Foundation

/// Runs its own independent TimerEngine/PomodoroStateStore, not a mirror of
/// the phone's — a paired Watch can't reach the phone's App Group
/// container, so it uses its own local UserDefaults.standard instead
/// (nothing shared, nothing to register). This means every action works
/// immediately regardless of connectivity; WatchConnectivityRelay is only
/// how the two sides stay in sync with each other after the fact, not a
/// requirement for the watch to function.
@MainActor
final class WatchTimerViewModel: ObservableObject {
    @Published private(set) var state: PomodoroState
    @Published private(set) var accentColor: AccentColorOption
    @Published private(set) var durations: PomodoroDurations

    private let engine: TimerEngine
    private let store: PomodoroStateStore
    private let relay: WatchConnectivityRelay
    private var ticker: Timer?

    init(relay: WatchConnectivityRelay) {
        self.relay = relay
        let store = PomodoroStateStore(defaults: .standard)
        self.store = store
        let loadedState = store.loadState()
        let loadedDurations = store.loadDurations()
        self.engine = TimerEngine(state: loadedState, durations: loadedDurations)
        self.state = loadedState
        self.accentColor = store.loadAccentColor()
        self.durations = loadedDurations

        relay.onReceive = { [weak self] state, accentColor, durations in
            self?.adopt(state: state, accentColor: accentColor, durations: durations)
        }
        startTicker()
    }

    func start() {
        engine.start()
        persistAndSync()
    }

    func pause() {
        engine.pause()
        persistAndSync()
    }

    func resume() {
        engine.resume()
        persistAndSync()
    }

    func skip() {
        engine.skip()
        persistAndSync()
    }

    func restart() {
        engine.reset()
        persistAndSync()
    }

    /// Applies a state update that arrived from the phone via
    /// WatchConnectivityRelay — last write wins, same spirit as the
    /// phone/widget reconciliation this mirrors.
    private func adopt(state: PomodoroState, accentColor: AccentColorOption, durations: PomodoroDurations) {
        engine.reload(state)
        engine.updateDurations(durations)
        self.state = state
        self.accentColor = accentColor
        self.durations = durations
        store.save(state)
        store.save(accentColor)
        store.save(durations)
    }

    private func catchUpIfNeeded() {
        if engine.catchUpIfExpired() {
            persistAndSync()
        } else {
            state = engine.state
        }
    }

    private func persistAndSync() {
        state = engine.state
        store.save(state)
        relay.send(state: state, accentColor: accentColor, durations: durations)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.catchUpIfNeeded() }
        }
    }
}
