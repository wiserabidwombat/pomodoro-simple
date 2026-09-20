// Pomodoro/LiveActivity/LiveActivityController.swift
import ActivityKit
import Foundation
import os

final class LiveActivityController: LiveActivityControlling {
    private let logger = Logger(subsystem: "com.aarontilley.pomodoro", category: "LiveActivity")

    // Always resolved fresh from ActivityKit's own bookkeeping rather than
    // cached in a stored property: this instance may be a brand new object
    // (e.g. the app process was relaunched after sitting locked for a full
    // session) with no memory of an activity a *previous* instance started,
    // even though that activity is still alive on the Lock Screen. Trusting
    // an in-memory reference here meant end() silently no-op'd on the
    // orphaned activity (leaving a stale, frozen "00:00" card behind after
    // Restart+Start) and update() couldn't push phase changes to it either.
    private var currentActivity: Activity<PomodoroActivityAttributes>? {
        Activity<PomodoroActivityAttributes>.activities.first
    }

    func start(state: PomodoroState, accentColor: AccentColorOption) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.error("start() aborted: Live Activities not enabled (areActivitiesEnabled == false)")
            return
        }
        endAllActivities()
        let content = ActivityContent(state: Self.contentState(state, accentColor), staleDate: nil)
        do {
            let activity = try Activity.request(attributes: PomodoroActivityAttributes(), content: content)
            logger.log("start() requested activity id=\(activity.id, privacy: .public)")
        } catch {
            logger.error("start() Activity.request threw: \(String(describing: error), privacy: .public)")
        }
    }

    func update(state: PomodoroState, accentColor: AccentColorOption) {
        guard let activity = currentActivity else {
            logger.error("update() aborted: no active Live Activity found")
            return
        }
        let content = ActivityContent(state: Self.contentState(state, accentColor), staleDate: nil)
        logger.log("update() calling activity.update on id=\(activity.id, privacy: .public) pausedAt=\(state.pausedAt?.description ?? "nil", privacy: .public)")
        Task {
            await activity.update(content)
            logger.log("update() activity.update completed for id=\(activity.id, privacy: .public)")
        }
    }

    func end() {
        endAllActivities()
    }

    private func endAllActivities() {
        for activity in Activity<PomodoroActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func contentState(_ state: PomodoroState, _ accentColor: AccentColorOption) -> PomodoroActivityAttributes.ContentState {
        PomodoroActivityAttributes.ContentState(
            phase: state.phase,
            startDate: state.startDate,
            endDate: state.endDate,
            pausedAt: state.pausedAt,
            accentColor: accentColor
        )
    }
}
