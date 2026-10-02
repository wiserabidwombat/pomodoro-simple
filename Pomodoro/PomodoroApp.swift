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

/// Wording that differs between iPhone and iPad: iPad has no StandBy,
/// Dynamic Island, Live Activities, or Action Button.
@MainActor
enum DeviceCopy {
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    /// For sentences like "while your phone is locked".
    static var device: String { isPad ? "iPad" : "phone" }
}

private struct RootView: View {
    @StateObject private var viewModel = TimerViewModel(
        historyStore: AppEnvironment.historyStore,
        liveActivity: LiveActivityController(),
        alerting: SystemPhaseChangeAlert()
    )
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab = AppTab.timer

    private enum AppTab: Hashable, CaseIterable {
        case timer, stats, settings

        var title: String {
            switch self {
            case .timer: return "Timer"
            case .stats: return "Stats"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .timer: return "timer"
            case .stats: return "chart.bar"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        // Adaptive layout: the tab bar on iPhone (and iPad in narrow Split
        // View / Slide Over), a sidebar on iPad's wider layouts.
        // horizontalSizeClass already accounts for multitasking width, not
        // just the device. Both share selectedTab, so deep links and the
        // notification tap land on the Timer either way.
        Group {
            if horizontalSizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
            }
        }
        .background(tabShortcuts)
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
            case .background:
                viewModel.sceneDidEnterBackground()
            default:
                break
            }
        }
    }

    private var tabLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                screen(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
    }

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: Binding<AppTab?>(
                get: { selectedTab },
                set: { if let tab = $0 { selectedTab = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.systemImage)
            }
            .navigationTitle("Simple Timer")
        } detail: {
            ZStack {
                // Full width behind everything, so a holiday theme's tint
                // reaches the edges instead of stopping at the column.
                ThemedBackground(theme: viewModel.activeTheme)
                // Stats and Settings are capped and centered so their lists
                // don't stretch edge to edge on a 13-inch screen. The Timer
                // isn't: its content is already centered, and that way its
                // drifting theme particles use the whole screen.
                screen(for: selectedTab)
                    .frame(maxWidth: selectedTab == .timer ? .infinity : 640)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// ⌘1–⌘3 switch between Timer, Stats, and Settings with a keyboard
    /// (iPad lists them when you hold ⌘). Invisible buttons, since keyboard
    /// shortcuts need a control to hang on; opacity 0 keeps them working.
    private var tabShortcuts: some View {
        ZStack {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                Button(tab.title) { selectedTab = tab }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .timer:
            TimerView(viewModel: viewModel)
        case .stats:
            StatsView(viewModel: viewModel, historyStore: AppEnvironment.historyStore)
        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }
}
