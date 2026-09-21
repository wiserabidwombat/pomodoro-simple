// Pomodoro/WatchSync/WatchSyncSending.swift
import Foundation

/// Seam around WatchConnectivityRelay so TimerViewModel is unit-testable —
/// a real WCSession needs actual device/simulator pairing infrastructure
/// XCTest doesn't have, mirroring LiveActivityControlling's reason for
/// existing.
protocol WatchSyncSending {
    func send(state: PomodoroState, accentColor: AccentColorOption, durations: PomodoroDurations)
}

extension WatchConnectivityRelay: WatchSyncSending {}

final class FakeWatchSync: WatchSyncSending {
    private(set) var sentStates: [PomodoroState] = []

    func send(state: PomodoroState, accentColor: AccentColorOption, durations: PomodoroDurations) {
        sentStates.append(state)
    }
}
