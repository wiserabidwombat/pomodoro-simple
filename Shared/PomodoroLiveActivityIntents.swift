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

/// Shared by all three intents: persist the engine's new state, keep the
/// backup notification in sync with the new endDate, and push the change to
/// the running Live Activity directly from this process.
@MainActor
private func applyAndPush(_ engine: TimerEngine, accentColor: AccentColorOption, store: PomodoroStateStore, notifications: NotificationScheduler) async {
    let newState = engine.state
    persistPomodoroState(newState, store: store, notifications: notifications)
    reloadIdlePomodoroWidget()
    guard let activity = currentActivity() else {
        intentLogger.error("applyAndPush() aborted: no active Live Activity found")
        return
    }
    // Only stale-mark while actually counting down — see the matching
    // comment in LiveActivityController.update().
    let staleDate = newState.pausedAt == nil ? newState.endDate : nil
    let content = ActivityContent(
        state: PomodoroActivityAttributes.ContentState(
            phase: newState.phase,
            startDate: newState.startDate,
            endDate: newState.endDate,
            pausedAt: newState.pausedAt,
            accentColor: accentColor
        ),
        staleDate: staleDate
    )
    intentLogger.log("applyAndPush() persisted \(newState.phase.rawValue, privacy: .public)(cycles=\(newState.completedWorkCycles, privacy: .public)) to store, pushing activity.update() id=\(activity.id, privacy: .public)")
    await activity.update(content)
    intentLogger.log("applyAndPush() activity.update() completed id=\(activity.id, privacy: .public)")
}

struct StartPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Focus Session"

    @MainActor
    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let engine = TimerEngine(state: store.loadState(), durations: store.loadDurations())
        engine.start()
        let newState = engine.state
        let accentColor = store.loadAccentColor()
        persistPomodoroState(newState, store: store, notifications: notifications)
        reloadIdlePomodoroWidget()

        // Unlike Pause/Resume/Skip, there may be no existing Live Activity to
        // update (or a stale one orphaned from a previous process — see
        // LiveActivityController's fix for the same issue), so this sweeps
        // any existing activities before requesting a fresh one.
        for activity in Activity<PomodoroActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        // staleDate omitted on the initial request — see the matching
        // comment in LiveActivityController.start() for why.
        let content = ActivityContent(
            state: PomodoroActivityAttributes.ContentState(
                phase: newState.phase,
                startDate: newState.startDate,
                endDate: newState.endDate,
                pausedAt: newState.pausedAt,
                accentColor: accentColor
            ),
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
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let beforeState = store.loadState()
        let engine = TimerEngine(state: beforeState, durations: store.loadDurations())
        let caughtUp = engine.catchUpIfExpired()
        engine.pause()
        logTransition("Pause", before: beforeState, after: engine.state, caughtUp: caughtUp)
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}

struct ResumePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let beforeState = store.loadState()
        let engine = TimerEngine(state: beforeState, durations: store.loadDurations())
        let caughtUp = engine.catchUpIfExpired()
        engine.resume()
        logTransition("Resume", before: beforeState, after: engine.state, caughtUp: caughtUp)
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}

struct SkipPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip"

    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let beforeState = store.loadState()
        let engine = TimerEngine(state: beforeState, durations: store.loadDurations())
        let caughtUp = engine.catchUpIfExpired()
        engine.skip()
        logTransition("Skip", before: beforeState, after: engine.state, caughtUp: caughtUp)
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}

/// Shown in place of Pause/Skip once the current phase's countdown has
/// actually reached zero (see PomodoroLiveActivityWidget's isStale
/// handling) — nothing runs in the background when a phase naturally
/// expires, so without this the Live Activity just sits frozen until the
/// app is opened. Deliberately does NOT also call skip(): catchUpIfExpired()
/// alone already advances to the next phase, and Skip additionally calling
/// .skip() on top of that is what caused the "one tap silently advances
/// twice" bug this intent replaces for the expired case.
struct AdvancePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Continue"

    func perform() async throws -> some IntentResult {
        guard IntentActionGate.begin() else { return .result() }
        defer { IntentActionGate.end() }
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let beforeState = store.loadState()
        let engine = TimerEngine(state: beforeState, durations: store.loadDurations())
        let caughtUp = engine.catchUpIfExpired()
        logTransition("Advance", before: beforeState, after: engine.state, caughtUp: caughtUp)
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}
