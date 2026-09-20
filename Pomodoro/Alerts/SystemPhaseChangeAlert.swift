// Pomodoro/Alerts/SystemPhaseChangeAlert.swift
import AudioToolbox
import Intents
import UIKit

final class SystemPhaseChangeAlert: PhaseChangeAlerting {
    private let store: PomodoroStateStore

    init(store: PomodoroStateStore = PomodoroStateStore()) {
        self.store = store
    }

    func alertPhaseChange() {
        if store.loadSilenceDuringFocus(), INFocusStatusCenter.default.focusStatus.isFocused == true {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard store.loadSoundEnabled() else { return }
        AudioServicesPlaySystemSound(store.loadChime().rawValue)
    }
}
