// Pomodoro/Alerts/PhaseChangeAlerting.swift
import Foundation

/// Seam around UIKit/AudioToolbox so TimerViewModel is unit-testable — the
/// real implementation (Task 8) plays a haptic + sound when a phase
/// completes naturally while the app is in the foreground (the spec's
/// backup path — a backgrounded phase-end is instead covered by the local
/// notification scheduled in NotificationScheduler).
protocol PhaseChangeAlerting {
    func alertPhaseChange()
}

final class FakePhaseChangeAlert: PhaseChangeAlerting {
    private(set) var alertCount = 0

    func alertPhaseChange() {
        alertCount += 1
    }
}
