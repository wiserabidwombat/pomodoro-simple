// PomodoroWatch/PomodoroWatchApp.swift
import SwiftUI

@main
struct PomodoroWatchApp: App {
    @StateObject private var viewModel = WatchTimerViewModel(relay: WatchConnectivityRelay())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchTimerView(viewModel: viewModel)
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.sceneDidBecomeActive()
            case .background:
                viewModel.sceneDidEnterBackground()
            default:
                break
            }
        }
    }
}
