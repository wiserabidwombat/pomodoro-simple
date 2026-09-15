// PomodoroWidget/PomodoroLiveActivityWidget.swift
import WidgetKit
import SwiftUI
import ActivityKit

struct PomodoroLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            PomodoroLiveActivityView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PomodoroLiveActivityView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, pauseTime: context.state.pausedAt, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 40)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

struct PomodoroLiveActivityView: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            Text(state.phase.displayName)
                .font(.headline)
            Text(timerInterval: state.startDate...state.endDate, pauseTime: state.pausedAt, countsDown: true)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 16) {
                if state.pausedAt == nil {
                    Button(intent: PausePomodoroIntent()) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                } else {
                    Button(intent: ResumePomodoroIntent()) {
                        Label("Resume", systemImage: "play.fill")
                    }
                }
                Button(intent: SkipPomodoroIntent()) {
                    Label("Skip", systemImage: "forward.fill")
                }
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(state.accentColor.color)
        .padding()
        // This is what actually paints the Lock Screen/StandBy banner black;
        // .containerBackground does not apply to Live Activities.
        .activityBackgroundTint(.black)
    }
}
