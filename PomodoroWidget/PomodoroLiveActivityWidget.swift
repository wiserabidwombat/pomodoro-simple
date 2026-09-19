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
                if context.state.pausedAt != nil {
                    Text(context.state.formattedRemainingWhilePaused)
                        .monospacedDigit()
                        .frame(width: 40)
                } else {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                }
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
            if state.pausedAt != nil {
                Text(state.formattedRemainingWhilePaused)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                // Text(timerInterval:) reserves a wider bounding box than it
                // visually needs (to avoid jitter as the digit count
                // changes) and renders left-aligned within it by default —
                // multilineTextAlignment forces the glyphs themselves to
                // center within that reserved box.
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 16) {
                // Fixed width so the Skip button doesn't shift when this
                // label's text changes length between "Pause" and "Resume".
                Group {
                    if state.pausedAt == nil {
                        Button(intent: PausePomodoroIntent()) {
                            Label("Pause", systemImage: "pause.fill")
                        }
                    } else {
                        Button(intent: ResumePomodoroIntent()) {
                            Label("Resume", systemImage: "play.fill")
                        }
                    }
                }
                .frame(width: 110)
                Button(intent: SkipPomodoroIntent()) {
                    Label("Skip", systemImage: "forward.fill")
                }
            }
            .buttonStyle(.bordered)
        }
        // Without this, the block shrinks to fit whichever countdown text is
        // narrower (the static paused string vs. the live timer text) and
        // re-centers within the banner, which reads as the whole thing
        // jumping to the left edge whenever pause/resume/skip is tapped.
        .frame(maxWidth: .infinity)
        .foregroundStyle(state.accentColor.color)
        .padding()
        // This is what actually paints the Lock Screen/StandBy banner black;
        // .containerBackground does not apply to Live Activities.
        .activityBackgroundTint(.black)
    }
}
