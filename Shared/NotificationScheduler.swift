// Shared/NotificationScheduler.swift
import Foundation
import UserNotifications

final class NotificationScheduler {
    private let center: UNUserNotificationCenter
    private let identifier = "pomodoro.phaseEnd"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }

    func schedulePhaseEnd(phase: PomodoroPhase, endDate: Date) {
        cancelPhaseEnd()
        let content = UNMutableNotificationContent()
        content.title = phase.displayName
        content.body = Self.body(for: phase)
        content.sound = .default
        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelPhaseEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    static func body(for phase: PomodoroPhase) -> String {
        phase == .work ? "Focus session complete. Time for a break." : "Break's over. Back to focus."
    }
}
