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
    let contentState = PomodoroActivityAttributes.ContentState(newState, accentColor: accentColor)
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
    let engine = TimerEngine(state: beforeState, durations: store.loadDurations())
    let completed = engine.catchUpIfExpired()
    if let completed {
        recordNaturalCompletion(completed, store: store)
    }
    action(engine)
    logTransition(label, before: beforeState, after: engine.state, caughtUp: completed != nil)
    await applyAndPush(engine.state, accentColor: store.loadAccentColor(), store: store, notifications: NotificationScheduler())
}

struct StartPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Focus Session"

    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState(), durations: store.loadDurations())
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .result() }
        // staleDate omitted on the initial request — see the matching
        // comment in LiveActivityController.start() for why.
        let content = ActivityContent(
            state: PomodoroActivityAttributes.ContentState(newState, accentColor: store.loadAccentColor()),
            staleDate: nil
        )
        do {
            _ = try Activity.request(attributes: PomodoroActivityAttributes(), content: content)
        } catch {
            intentLogger.error("StartPomodoroIntent Activity.request threw: \(String(describing: error), privacy: .public)")
        }
        return .result()
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
