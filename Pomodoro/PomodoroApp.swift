import AppIntents
import SwiftUI
import UIKit
import SwiftData
import UserNotifications

@main
struct PomodoroApp: App {
    // Held strongly here since UNUserNotificationCenter's delegate
    // property doesn't retain it — nothing else would keep it alive.
    private let notificationDelegate = PhaseEndNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // Refresh the profile names Siri can match in "Start … with …".
        PomodoroAppShortcuts.updateAppShortcutParameters()
        // Also runs when the app is launched in the background (a Lock
        // Screen or widget button), so those changes reach the watch too.
        PhoneWatchSync.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// The iPhone's end of the Apple Watch link. Sends the current state,
/// active profile, color, and today's progress whenever any of them change
/// (via WatchSyncHook), and applies what the watch sends back: timer changes
/// made on the wrist, and Focus sessions finished there (so they reach
/// Stats even if the phone app wasn't running).
enum PhoneWatchSync {
    /// Kept alive here for the whole process — WCSession only holds its
    /// delegate weakly.
    static let relay = WatchConnectivityRelay()
    /// True while applying a state that just came *from* the watch, so it
    /// isn't immediately sent straight back. An echo could arrive after the
    /// user's next tap on the watch and undo it (e.g. Pause then Resume
    /// quickly would bounce back to paused).
    private static var isApplyingWatchState = false

    static func start() {
        WatchSyncHook.stateDidChange = {
            guard !isApplyingWatchState else { return }
            PomodoroStateStore().save(stateChangedAt: Date())
            sendCurrentState()
        }
        WatchSyncHook.settingsDidChange = {
            sendCurrentState()
        }
        relay.onReceivePayload = { payload in
            Task { @MainActor in applyFromWatch(payload) }
        }
        relay.onReceiveCompletedSession = { completed in
            recordFromWatch(completed)
        }
        relay.onWatchAvailabilityChange = {
            sendCurrentState()
        }
        sendCurrentState()
    }

    /// Also called each time the app comes to the foreground, which covers
    /// a holiday theme starting or ending with the date.
    static func sendCurrentState() {
        let store = PomodoroStateStore()
        relay.send(WatchSyncPayload(
            state: store.loadState(),
            stateChangedAt: store.loadStateChangedAt(),
            accentColor: store.loadEffectiveAccentColor(),
            profile: store.loadActiveProfile(),
            profileLabel: store.loadActiveProfileLabel(),
            todayCount: store.loadCachedTodayCount(),
            dailyGoal: store.loadDailyGoal()
        ))
    }

    /// The watch is just another writer to the shared store, like the Lock
    /// Screen intents: save it, keep the phase-end notification and widget
    /// in step, and move the Live Activity to match. The app's own ticker
    /// picks the new state up from the store on its next beat.
    ///
    /// Only a change newer than the phone's own is applied. An older one
    /// (the watch reconnecting with a change from before the phone's latest)
    /// is answered with the phone's state, so the watch catches up instead.
    @MainActor
    private static func applyFromWatch(_ payload: WatchSyncPayload) {
        let store = PomodoroStateStore()
        let state = payload.state
        guard payload.stateChangedAt > store.loadStateChangedAt() else {
            if payload.stateChangedAt < store.loadStateChangedAt() {
                sendCurrentState()
            }
            return
        }
        isApplyingWatchState = true
        persistPomodoroState(state, store: store, notifications: NotificationScheduler())
        store.save(stateChangedAt: payload.stateChangedAt)
        isApplyingWatchState = false
        reloadIdlePomodoroWidget()
        let liveActivity = LiveActivityController()
        let accentColor = store.loadEffectiveAccentColor()
        if !state.sessionActive {
            liveActivity.end()
        } else if liveActivity.needsRestart {
            liveActivity.start(state: state, accentColor: accentColor)
        } else {
            liveActivity.update(state: state, accentColor: accentColor)
        }
    }

    /// Queued exactly like a Lock Screen completion; the app imports it into
    /// history on its next tick (de-duplicated, in case the phone noticed
    /// the same session end on its own). Then sends back today's count so
    /// the watch shows the phone's number, not just its own.
    private static func recordFromWatch(_ completed: PendingCompletedSession) {
        let store = PomodoroStateStore()
        store.enqueueCompletedSession(completed)
        countTowardToday(completed.endedAt, store: store)
        reloadIdlePomodoroWidget()
        sendCurrentState()
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
///
/// The container is held in its own static rather than as a local inside
/// the historyStore initializer: a ModelContext doesn't keep its
/// ModelContainer alive, so the container must be owned for as long as its
/// context is in use.
///
/// The container is opened through HistoryContainer, which never crashes: a
/// store that won't open is moved aside and replaced, or, failing that,
/// history runs in memory for this launch (see HistoryContainer).
@MainActor
private enum AppEnvironment {
    private static let opened = HistoryContainer.open(
        protectedDataAvailable: UIApplication.shared.isProtectedDataAvailable
    )
    static let container: ModelContainer = opened.container
    static let historyStore = HistoryStore(context: container.mainContext, health: opened.health)
}

private struct RootView: View {
    @StateObject private var viewModel = TimerViewModel(
        historyStore: AppEnvironment.historyStore,
        liveActivity: LiveActivityController(),
        alerting: SystemPhaseChangeAlert()
    )
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = AppTab.timer

    private enum AppTab: Hashable {
        case timer, stats, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TimerView(viewModel: viewModel)
                .tabItem { Label("Timer", systemImage: "timer") }
                .tag(AppTab.timer)
            StatsView(viewModel: viewModel, historyStore: AppEnvironment.historyStore)
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppTab.stats)
            SettingsView(viewModel: viewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(.dark)
        // The selected tab's icon (and any other control still using the
        // system tint, like Settings' steppers) follows the accent color
        // instead of the default blue.
        .tint(viewModel.displayAccent.color)
        // Arriving from the Live Activity or a widget (both open a
        // pomodoro:// URL) or from tapping the phase-end notification always
        // lands on the Timer — otherwise the app reopened on whatever tab
        // was last showing, e.g. Settings. Just switching back to the app
        // normally still keeps your place.
        .onOpenURL { url in
            if url.scheme == PomodoroDeepLink.scheme {
                selectedTab = .timer
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openTimerTab)) { _ in
            selectedTab = .timer
        }
        // Lives here rather than on TimerView so it keeps working whichever
        // tab is showing. `initial: true` matters: without it this never
        // fires for the scene's first .active on a cold launch.
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.sceneDidBecomeActive()
                PhoneWatchSync.sendCurrentState()
            case .background:
                viewModel.sceneDidEnterBackground()
            default:
                break
            }
        }
    }
}
