// Pomodoro/LiveActivity/LiveActivityController.swift
import ActivityKit
import Foundation
import os

final class LiveActivityController: LiveActivityControlling {
    private var activity: Activity<PomodoroActivityAttributes>?
    private let logger = Logger(subsystem: "com.aarontilley.pomodoro", category: "LiveActivity")

    func start(state: PomodoroState, accentColor: AccentColorOption) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.error("start() aborted: Live Activities not enabled (areActivitiesEnabled == false)")
            return
        }
        let content = ActivityContent(state: Self.contentState(state, accentColor), staleDate: nil)
        do {
            activity = try Activity.request(attributes: PomodoroActivityAttributes(), content: content)
            logger.log("start() requested activity id=\(self.activity?.id ?? "nil", privacy: .public)")
        } catch {
            logger.error("start() Activity.request threw: \(String(describing: error), privacy: .public)")
        }
    }

    func update(state: PomodoroState, accentColor: AccentColorOption) {
        guard let activity else {
            logger.error("update() aborted: no activity reference held by this process")
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
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
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
