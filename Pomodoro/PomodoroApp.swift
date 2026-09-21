import SwiftUI
import SwiftData

@main
struct PomodoroApp: App {
    private let modelContainer: ModelContainer
    private let historyStore: HistoryStore
    @StateObject private var viewModel: TimerViewModel

    init() {
        let container = try! ModelContainer(for: CompletedSession.self)
        modelContainer = container
        let history = HistoryStore(context: container.mainContext)
        historyStore = history

        // Kept alive by TimerViewModel's strong reference to it as
        // watchSync — WCSession holds its delegate weakly, so nothing
        // else keeps this from being deallocated right after init().
        let watchRelay = WatchConnectivityRelay()
        let vm = TimerViewModel(
            historyStore: history,
            liveActivity: LiveActivityController(),
            alerting: SystemPhaseChangeAlert(),
            watchSync: watchRelay
        )
        _viewModel = StateObject(wrappedValue: vm)

        // The watch is, from the phone's perspective, just another writer
        // to the same shared store the widget extension already uses —
        // reusing refreshFromSharedState() means no new reconciliation
        // logic is needed here.
        watchRelay.onReceive = { [weak vm] state, accentColor, durations in
            let store = PomodoroStateStore()
            store.save(state)
            store.save(accentColor)
            store.save(durations)
            reloadIdlePomodoroWidget()
            vm?.refreshFromSharedState()
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                TimerView(viewModel: viewModel)
                    .tabItem { Label("Timer", systemImage: "timer") }
                StatsView(viewModel: viewModel, historyStore: historyStore)
                    .tabItem { Label("Stats", systemImage: "chart.bar") }
                SettingsView(viewModel: viewModel)
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .preferredColorScheme(.dark)
        }
    }
}
