import SwiftUI
import SwiftData
import UserNotifications

@main
struct PomodoroApp: App {
    private let modelContainer: ModelContainer
    private let historyStore: HistoryStore
    // Held strongly here since UNUserNotificationCenter's delegate
    // property doesn't retain it — nothing else would keep it alive.
    private let notificationDelegate = PhaseEndNotificationDelegate()
    @StateObject private var viewModel: TimerViewModel

    init() {
        let container = try! ModelContainer(for: CompletedSession.self)
        modelContainer = container
        let history = HistoryStore(context: container.mainContext)
        historyStore = history
        UNUserNotificationCenter.current().delegate = notificationDelegate
        _viewModel = StateObject(wrappedValue: TimerViewModel(
            historyStore: history,
            liveActivity: LiveActivityController(),
            alerting: SystemPhaseChangeAlert()
        ))
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
