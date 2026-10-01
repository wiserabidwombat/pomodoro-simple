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
        guard response.notification.request.content.categoryIdentifier == NotificationScheduler.phaseEndCategory else {
            completionHandler()
            return
        }
        // Tapping the notification opens the app — take it to the Timer.
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openTimerTab, object: nil)
            }
            completionHandler()
            return
        }
        guard response.actionIdentifier == UNNotificationDismissActionIdentifier else {
            completionHandler()
            return
        }
        // Must finish on the main actor: UIKit updates the app snapshot when the
        // completion handler runs, and asserts on the main thread. Calling it from
        // the cooperative pool crashed background launches (e.g. dismissing on Watch).
        Task { @MainActor in
            _ = try? await AdvancePomodoroIntent().perform()
            completionHandler()
        }
    }

    /// Without implementing this, a notification that fires while the app
    /// is in the foreground is silently suppressed (the system's default
    /// once any delegate is set) — opting in to showing the banner anyway.
    /// No .sound: in the foreground the app's own ticker already plays the
    /// chosen chime + haptic (and honors "Silence Alerts During Focus"),
    /// so the notification's sound on top of it was a double alert.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

extension Notification.Name {
    /// Posted when the app is opened from the phase-end notification;
    /// RootView switches to the Timer tab in response.
    static let openTimerTab = Notification.Name("pomodoro.openTimerTab")
}
