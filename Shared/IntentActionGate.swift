// Shared/IntentActionGate.swift
import Foundation

/// Debounces rapid repeat taps on the StandBy/Home Screen widget's and Live
/// Activity's Pause/Resume/Skip buttons. Each tap wakes the app process and
/// runs its LiveActivityIntent, but the visible widget refresh lags the tap
/// by several seconds — WidgetKit pauses that widget's timeline reloads for
/// the whole tap-to-completion round trip (see PomodoroLiveActivityIntents.swift)
/// — so without this, tapping again before seeing the first tap take effect
/// would silently apply the action a second (or third) time.
enum IntentActionGate {
    private static let key = "pomodoro.actionInFlightSince"
    // Comfortably longer than the ~3.3s tap-to-completion round trip
    // observed on-device, so a flag left behind by a process that was
    // killed mid-perform() self-heals instead of permanently blocking
    // every future tap.
    private static let staleAfter: TimeInterval = 8

    /// Call at the very top of an intent's perform(). Returns false if
    /// another action is already in flight, in which case perform() should
    /// no-op rather than mutate state again.
    static func begin(now: Date = Date(), defaults: UserDefaults = AppGroup.defaults) -> Bool {
        if let since = defaults.object(forKey: key) as? Date, now.timeIntervalSince(since) < staleAfter {
            return false
        }
        defaults.set(now, forKey: key)
        return true
    }

    static func end(defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: key)
    }
}
