// Shared/PomodoroLiveActivityIntents.swift
import AppIntents
import ActivityKit
import Foundation
import os

private let intentLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "LiveActivityIntents")

// LiveActivityIntent's perform() is documented to run in the app's own
// process (briefly woken in the background), not the widget extension's —
// so this file must be compiled into both targets (hence living in
// Shared/, not PomodoroWidget/) for Activity<Attributes>.activities to see
// anything when a button is tapped from the Lock Screen/StandBy.
@MainActor
private func currentActivity() -> Activity<PomodoroActivityAttributes>? {
    Activity<PomodoroActivityAttributes>.activities.first
}

/// Diagnostic only — logs the phase/cycle count before and after an
/// intent's mutation, and separately flags when catchUpIfExpired() did
/// something, so a real-device Console capture can show exactly what each
/// Lock Screen/StandBy tap actually computed (useful for diagnosing state
/// drift that's hard to reproduce locally).
private func logTransition(_ label: String, before: PomodoroState, after: PomodoroState, caughtUp: Bool) {
    intentLogger.log("""
    \(label, privacy: .public): caughtUpFirst=\(caughtUp, privacy: .public) \
    \(before.phase.rawValue, privacy: .public)(cycles=\(before.completedWorkCycles, privacy: .public)) -> \
    \(after.phase.rawValue, privacy: .public)(cycles=\(after.completedWorkCycles, privacy: .public)) \
    endDate=\(after.endDate.description, privacy: .public)
    """)
}

/// Persists the new state, keeps the backup notification and idle widget in
/// sync with it, and pushes it to the running Live Activity directly from
/// this process.
@MainActor
private func applyAndPush(_ newState: PomodoroState, accentColor: AccentColorOption, store: PomodoroStateStore, notifications: NotificationScheduler) async {
    persistPomodoroState(newState, store: store, notifications: notifications)
    reloadIdlePomodoroWidget()
    guard let activity = currentActivity() else {
        intentLogger.error("applyAndPush() aborted: no active Live Activity found")
        return
    }
    let contentState = PomodoroActivityAttributes.ContentState(newState, accentColor: accentColor, profileName: store.loadActiveProfileLabel())
    let content = ActivityContent(state: contentState, staleDate: contentState.staleDate)
    intentLogger.log("applyAndPush() persisted \(newState.phase.rawValue, privacy: .public)(cycles=\(newState.completedWorkCycles, privacy: .public)) to store, pushing activity.update() id=\(activity.id, privacy: .public)")
    await activity.update(content)
    intentLogger.log("applyAndPush() activity.update() completed id=\(activity.id, privacy: .public)")
}

/// The whole body of Pause/Resume/Skip/Continue, which differ only in the
/// one engine call they make: debounce, load the shared state, catch up a
/// phase that already ran out (queueing it for history if it was Focus),
/// apply the tapped action, then persist and push.
@MainActor
private func performPomodoroAction(_ label: String, _ action: (TimerEngine) -> Void) async {
    guard IntentActionGate.begin() else { return }
    defer { IntentActionGate.end() }
    let store = PomodoroStateStore()
    let beforeState = store.loadState()
    let engine = TimerEngine(state: beforeState, profile: store.loadActiveProfile())
    let completed = engine.catchUpIfExpired()
    if let completed {
        recordNaturalCompletion(completed, store: store)
    }
    action(engine)
    logTransition(label, before: beforeState, after: engine.state, caughtUp: completed != nil)
    await applyAndPush(engine.state, accentColor: store.loadAccentColor(), store: store, notifications: NotificationScheduler())
}

/// Starts a fresh session with the active profile — shared by the plain
/// Start intent (widget button, "Start Simple Timer") and the per-profile
/// one. Returns false, changing nothing, if a session is already running:
/// the Home Screen widget can still show Start for a moment after a session
/// began somewhere else (its refresh lags), and Siri can be asked to start
/// mid-session. Neither should wipe out the session in progress.
@MainActor
private func startSessionWithActiveProfile(store: PomodoroStateStore) async -> Bool {
    let current = store.loadState()
    guard !current.sessionActive else {
        reloadIdlePomodoroWidget()
        return false
    }
    let engine = TimerEngine(state: current, profile: store.loadActiveProfile())
    engine.start()
    let newState = engine.state
    persistPomodoroState(newState, store: store, notifications: NotificationScheduler())
    reloadIdlePomodoroWidget()

    // Unlike Pause/Resume/Skip, there may be no existing Live Activity to
    // update (or a stale one orphaned from a previous process — see
    // LiveActivityController's fix for the same issue), so this sweeps
    // any existing activities before requesting a fresh one.
    for activity in Activity<PomodoroActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return true }
    // staleDate omitted on the initial request — see the matching
    // comment in LiveActivityController.start() for why.
    let content = ActivityContent(
        state: PomodoroActivityAttributes.ContentState(newState, accentColor: store.loadAccentColor(), profileName: store.loadActiveProfileLabel()),
        staleDate: nil
    )
    do {
        _ = try Activity.request(attributes: PomodoroActivityAttributes(), content: content)
    } catch {
        intentLogger.error("startSessionWithActiveProfile Activity.request threw: \(String(describing: error), privacy: .public)")
    }
    return true
}

struct StartPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Focus Session"

    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        _ = await startSessionWithActiveProfile(store: PomodoroStateStore())
        return .result()
    }
}

/// "Start Deep Work with Simple Timer" — and the action to put on the
/// Action Button, or in any Shortcut, to start a particular profile in one
/// press. Makes the chosen profile the active one (just as picking it on
/// the Timer screen would), then starts. A LiveActivityIntent, so it runs
/// in the background and the Live Activity appears without opening the app.
struct StartProfileIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Timer Profile"
    static var description = IntentDescription("Starts a Focus session using one of your timer profiles.")

    @Parameter(title: "Profile")
    var profile: TimerProfileEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$profile)")
    }

    init() {}

    init(profile: TimerProfileEntity) {
        self.profile = profile
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentActionGate.begin() else { return .result(dialog: "One moment — still starting.") }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        guard !store.loadState().sessionActive else {
            reloadIdlePomodoroWidget()
            return .result(dialog: "A session is already running. Stop it first to switch profiles.")
        }
        guard let chosen = store.loadProfiles().first(where: { $0.id == profile.id }) else {
            return .result(dialog: "That timer profile doesn't exist anymore.")
        }
        store.saveActiveProfileID(chosen.id)
        _ = await startSessionWithActiveProfile(store: store)
        return .result(dialog: "Starting \(chosen.name).")
    }
}

struct PausePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"

    func perform() async throws -> some IntentResult {
        await performPomodoroAction("Pause") { $0.pause() }
        return .result()
    }
}

struct ResumePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        await performPomodoroAction("Resume") { $0.resume() }
        return .result()
    }
}

struct SkipPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip"

    func perform() async throws -> some IntentResult {
        await performPomodoroAction("Skip") { $0.skip() }
        return .result()
    }
}

/// Shown in place of Pause/Skip once the current phase's countdown has
/// actually reached zero (see PomodoroLiveActivityWidget's isStale
/// handling, and the idle widget's matching "Time's up" entry) — nothing
/// runs in the background when a phase naturally expires, so without this
/// the display just sits frozen until the app is opened. Deliberately does
/// NOT also call skip(): the catch-up alone already advances to the next
/// phase, and Skip additionally calling .skip() on top of that is what
/// caused the "one tap silently advances twice" bug this intent replaces
/// for the expired case.
struct AdvancePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Continue"

    func perform() async throws -> some IntentResult {
        await performPomodoroAction("Advance") { _ in }
        return .result()
    }
}
