// PomodoroWatch/PomodoroWatchApp.swift
import SwiftUI

@main
struct PomodoroWatchApp: App {
    @StateObject private var viewModel: WatchTimerViewModel

    init() {
        _viewModel = StateObject(wrappedValue: WatchTimerViewModel(relay: WatchConnectivityRelay()))
    }

    var body: some Scene {
        WindowGroup {
            WatchTimerView(viewModel: viewModel)
        }
    }
}
