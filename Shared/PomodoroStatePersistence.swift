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
        notifications.schedulePhaseEnd(phase: state.phase, endDate: state.endDate)
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
