// Pomodoro/Notifications/PhaseEndNotificationDelegate.swift
import Foundation
import UserNotifications

/// Registered as UNUserNotificationCenter's delegate so that *dismissing*
/// the phase-end notification advances the timer, the same way tapping
/// "Continue" on the Live Activity does — including when it's cleared on a
/// paired Apple Watch, since Notification Center state (read/dismissed) is
/// kept in sync between the two by the system, not by anything this app
/// does. Nothing else runs in the background when a phase naturally
/// expires, so without this the Live Activity/StandBy display just sits
/// frozen until the app is opened or a Lock Screen button is tapped.
final class PhaseEndNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard response.notification.request.content.categoryIdentifier == NotificationScheduler.phaseEndCategory,
              response.actionIdentifier == UNNotificationDismissActionIdentifier
        else {
            completionHandler()
            return
        }
        Task {
            _ = try? await AdvancePomodoroIntent().perform()
            completionHandler()
        }
    }

    /// Without implementing this, a notification that fires while the app
    /// is in the foreground is silently suppressed (the system's default
    /// once any delegate is set) — opting in to showing it anyway, which
    /// matches what happened before this delegate existed at all.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
