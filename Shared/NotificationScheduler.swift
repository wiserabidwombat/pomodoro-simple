// Shared/NotificationScheduler.swift
import Foundation
import UserNotifications

final class NotificationScheduler {
    private let center: UNUserNotificationCenter
    private let identifier = "pomodoro.phaseEnd"
    static let phaseEndCategory = "pomodoro.phaseEndCategory"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        // .customDismissAction is what lets *dismissing* this notification —
        // including clearing it on a paired Apple Watch, which mirrors and
        // stays in sync with the iPhone's Notification Center — wake the
        // app just long enough to advance the timer (see
        // PhaseEndNotificationDelegate), not just tapping into it. Safe to
        // register unconditionally and repeatedly: it's independent of
        // authorization status and setNotificationCategories is idempotent.
        let category = UNNotificationCategory(
            identifier: Self.phaseEndCategory,
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
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
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.phaseEndCategory
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
