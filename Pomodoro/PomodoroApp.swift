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
        _viewModel = StateObject(wrappedValue: TimerViewModel(
            historyStore: history,
            liveActivity: LiveActivityController(),
            alerting: SystemPhaseChangeAlert()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel, historyStore: historyStore)
        }
    }
}
