// Pomodoro/Alerts/SystemPhaseChangeAlert.swift
import AudioToolbox
import UIKit

final class SystemPhaseChangeAlert: PhaseChangeAlerting {
    func alertPhaseChange() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
    }
}
