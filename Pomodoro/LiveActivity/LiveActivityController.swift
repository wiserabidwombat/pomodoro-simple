// Pomodoro/LiveActivity/LiveActivityController.swift
import ActivityKit
import Foundation

final class LiveActivityController: LiveActivityControlling {
    private var activity: Activity<PomodoroActivityAttributes>?

    func start(state: PomodoroState, accentColor: AccentColorOption) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: Self.contentState(state, accentColor), staleDate: nil)
        activity = try? Activity.request(attributes: PomodoroActivityAttributes(), content: content)
    }

    func update(state: PomodoroState, accentColor: AccentColorOption) {
        guard let activity else { return }
        let content = ActivityContent(state: Self.contentState(state, accentColor), staleDate: nil)
        Task { await activity.update(content) }
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
