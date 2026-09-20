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
    await activity.update(content)
}

struct PausePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.pause()
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}

struct ResumePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.resume()
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}

struct SkipPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let notifications = NotificationScheduler()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.skip()
        await applyAndPush(engine, accentColor: store.loadAccentColor(), store: store, notifications: notifications)
        return .result()
    }
}
