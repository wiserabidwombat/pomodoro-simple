// PomodoroWidget/PomodoroIdleWidgetIntents.swift
import AppIntents
import ActivityKit
import Foundation
import os

private let widgetIntentLogger = Logger(subsystem: "com.aarontilley.pomodoro", category: "IdleWidgetIntents")

/// Plain AppIntents (not LiveActivityIntent) for the idle/Home Screen
/// widget's own Pause/Resume/Skip buttons. LiveActivityIntent's defining
/// behavior is that it wakes the containing app's full process to run —
/// necessary for the Live Activity's buttons (see
/// PomodoroLiveActivityIntents.swift), but paying that same multi-second
/// app-wake cost for a plain widget tap is exactly what caused a several-
/// second delay and taps queueing up when tapped repeatedly. These run
/// directly in the widget extension instead, with no app-wake cost.
///
/// A Live Activity started by the app is a separate Activity<T> instance
/// as far as this process is concerned, so pushToLiveActivityIfPresent()
/// below is a best-effort attempt, not a guarantee — if
/// Activity<T>.activities comes back empty from the widget extension's own
/// process (this is the open question; see PomodoroLiveActivityIntents.swift's
/// history for why LiveActivityIntent's app-wake was originally used
/// instead), this silently does nothing extra, and the existing fallback
/// (TimerViewModel.refreshFromSharedState() correcting it next time the
/// app is foregrounded) still applies — no downside either way.
private func applyAndReload(_ engine: TimerEngine, accentColor: AccentColorOption, store: PomodoroStateStore) async {
    persistPomodoroState(engine.state, store: store, notifications: NotificationScheduler())
    reloadIdlePomodoroWidget()
    await pushToLiveActivityIfPresent(engine.state, accentColor: accentColor)
}

private func pushToLiveActivityIfPresent(_ state: PomodoroState, accentColor: AccentColorOption) async {
    let activities = Activity<PomodoroActivityAttributes>.activities
    widgetIntentLogger.log("pushToLiveActivityIfPresent() found \(activities.count, privacy: .public) activities")
    guard let activity = activities.first else { return }
    // Only stale-mark while actually counting down — see the matching
    // comment in LiveActivityController.update().
    let staleDate = state.pausedAt == nil ? state.endDate : nil
    let content = ActivityContent(
        state: PomodoroActivityAttributes.ContentState(
            phase: state.phase,
            startDate: state.startDate,
            endDate: state.endDate,
            pausedAt: state.pausedAt,
            accentColor: accentColor
        ),
        staleDate: staleDate
    )
    await activity.update(content)
    widgetIntentLogger.log("pushToLiveActivityIfPresent() activity.update completed id=\(activity.id, privacy: .public)")
}

struct WidgetPausePomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState(), durations: store.loadDurations())
        engine.catchUpIfExpired()
        engine.pause()
        await applyAndReload(engine, accentColor: store.loadAccentColor(), store: store)
        return .result()
    }
}

struct WidgetResumePomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState(), durations: store.loadDurations())
        engine.catchUpIfExpired()
        engine.resume()
        await applyAndReload(engine, accentColor: store.loadAccentColor(), store: store)
        return .result()
    }
}

struct WidgetSkipPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState(), durations: store.loadDurations())
        engine.catchUpIfExpired()
        engine.skip()
        await applyAndReload(engine, accentColor: store.loadAccentColor(), store: store)
        return .result()
    }
}
