import SwiftUI
import SwiftData
import UserNotifications

@main
struct PomodoroApp: App {
    // Held strongly here since UNUserNotificationCenter's delegate
    // property doesn't retain it — nothing else would keep it alive.
    private let notificationDelegate = PhaseEndNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Everything that touches SwiftData (and the ViewModel it feeds) is
/// constructed here rather than in PomodoroApp.init() — that init() runs on
/// every process launch, including a background wake purely to run a
/// Pause/Resume/Skip/Advance LiveActivityIntent (none of which touch
/// history), so building the ModelContainer there added that cost to every
/// such wake. SwiftUI only calls this View's init() when a window scene is
/// actually about to be shown, so a headless intent-triggered launch skips
/// it entirely.
private struct RootView: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var historyStore: HistoryStore

    init() {
        let container = try! ModelContainer(for: CompletedSession.self)
        let history = HistoryStore(context: container.mainContext)
        _historyStore = State(initialValue: history)
        _viewModel = StateObject(wrappedValue: TimerViewModel(
            historyStore: history,
            liveActivity: LiveActivityController(),
            alerting: SystemPhaseChangeAlert()
        ))
    }

    var body: some View {
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
