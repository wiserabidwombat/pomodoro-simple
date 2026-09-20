// PomodoroWidget/PomodoroIdleWidgetIntents.swift
import AppIntents
import Foundation

/// Plain AppIntents (not LiveActivityIntent) for the idle/Home Screen
/// widget's own Pause/Resume/Skip buttons. LiveActivityIntent's defining
/// behavior is that it wakes the containing app's full process to run —
/// necessary for the Live Activity's buttons (see
/// PomodoroLiveActivityIntents.swift), but paying that same multi-second
/// app-wake cost for a plain widget tap is exactly what caused a several-
/// second delay and taps queueing up when tapped repeatedly. These run
/// directly in the widget extension instead, with no app-wake cost.
///
/// They deliberately don't attempt to touch a Live Activity: that lookup is
/// only reliable from the app's own process (see
/// PomodoroLiveActivityIntents.swift's history). If one happens to be
/// visible at the same time, TimerViewModel.refreshFromSharedState()
/// corrects it the next time the app is foregrounded.
private func applyAndReload(_ engine: TimerEngine, store: PomodoroStateStore) {
    persistPomodoroState(engine.state, store: store, notifications: NotificationScheduler())
    reloadIdlePomodoroWidget()
}

struct WidgetPausePomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.pause()
        applyAndReload(engine, store: store)
        return .result()
    }
}

struct WidgetResumePomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.resume()
        applyAndReload(engine, store: store)
        return .result()
    }
}

struct WidgetSkipPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip"

    func perform() async throws -> some IntentResult {
        let store = PomodoroStateStore()
        let engine = TimerEngine(state: store.loadState())
        engine.catchUpIfExpired()
        engine.skip()
        applyAndReload(engine, store: store)
        return .result()
    }
}
