// Shared/PomodoroStatePersistence.swift
import Foundation
import WidgetKit

/// Saves state and keeps the backup local notification in sync with it —
/// shared by TimerViewModel, the Live Activity intents, and the idle
/// widget's own intents, which otherwise each duplicated this exact
/// save-then-schedule-or-cancel pairing.
func persistPomodoroState(_ state: PomodoroState, store: PomodoroStateStore, notifications: NotificationScheduler) {
    store.save(state)
    if state.sessionActive, state.pausedAt == nil {
        notifications.schedulePhaseEnd(phase: state.phase, endDate: state.endDate, playSound: store.loadSoundEnabled())
    } else {
        notifications.cancelPhaseEnd()
    }
}

/// The idle/Home Screen widget has no way to know the shared store changed
/// on its own — unlike the Live Activity, which is pushed to directly,
/// WidgetKit only re-renders when explicitly told to. One place for the
/// widget kind string so it can't drift between call sites.
func reloadIdlePomodoroWidget() {
    WidgetCenter.shared.reloadTimelines(ofKind: "PomodoroIdleWidget")
}

/// The one place a phase running out on its own gets its side effects,
/// whichever process noticed it: the app's ticker, a Lock Screen/StandBy/
/// widget button, or dismissing the phase-end notification. A completed
/// Focus session is queued for history (the app imports the queue into
/// SwiftData on its next catch-up) and bumps the widget's "Today" count.
/// Before this existed, only the app's own ticker recorded history, so a
/// Focus session finished via "Continue" on the Lock Screen — or by
/// dismissing its notification — never showed up in Stats at all.
func recordNaturalCompletion(_ completed: CompletedPhase, store: PomodoroStateStore, calendar: Calendar = .current) {
    guard completed.phase == .work else { return }
    // Profiles can only be switched while idle, so the active profile is
    // the one this session ran under.
    let profile = store.loadActiveProfile()
    store.enqueueCompletedSession(PendingCompletedSession(
        endedAt: completed.endedAt,
        duration: completed.duration,
        profileID: profile.id,
        profileName: profile.name
    ))
    if calendar.isDateInToday(completed.endedAt) {
        store.incrementCachedTodayCount(calendar: calendar)
    }
}
