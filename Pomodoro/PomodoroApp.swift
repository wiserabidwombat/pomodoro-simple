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

/// Built at most once per process, the first time something actually reads
/// `historyStore` — a `static let` is Swift's own guaranteed-once lazy
/// initializer, unlike `@StateObject`'s "only once" behavior, which only
/// applies to the sugared `@StateObject var x = Expr()` form. RootView used
/// to build its own ModelContainer inline inside a hand-written init() and
/// hand it to `StateObject(wrappedValue:)`; because that's a plain eager
/// function argument (not the sugared form), it was re-evaluated on every
/// RootView.init() call — and SwiftUI reconstructs RootView more than once
/// across an app's foreground lifetime (e.g. backgrounding to the Lock
/// Screen/StandBy and back). Each reconstruction opened a second SQLite
/// connection to the same on-disk store, and two live connections to one
/// SwiftData store is exactly the kind of thing that deadlocks — which is
/// what caused the app to hang after a background/foreground round trip.
/// Routing through this singleton instead means RootView.init() running
/// again just re-reads the same already-open store. It also still isn't
/// touched at all during a headless LiveActivityIntent wake, since nothing
/// in that path ever reads `AppEnvironment.historyStore`.
@MainActor
private enum AppEnvironment {
    static let historyStore: HistoryStore = {
        let container = try! ModelContainer(for: CompletedSession.self)
        return HistoryStore(context: container.mainContext)
    }()
}

private struct RootView: View {
    @StateObject private var viewModel = TimerViewModel(
        historyStore: AppEnvironment.historyStore,
        liveActivity: LiveActivityController(),
        alerting: SystemPhaseChangeAlert()
    )

    var body: some View {
        TabView {
            TimerView(viewModel: viewModel)
                .tabItem { Label("Timer", systemImage: "timer") }
            StatsView(viewModel: viewModel, historyStore: AppEnvironment.historyStore)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            SettingsView(viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
    }
}
