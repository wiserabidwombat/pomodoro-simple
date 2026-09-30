// PomodoroWatch/WatchTimerView.swift
import SwiftUI

struct WatchTimerView: View {
    @ObservedObject var viewModel: WatchTimerViewModel
    @State private var showingRestartConfirmation = false
    @State private var focusEndPrompt: FocusEndPrompt?

    private struct FocusEndPrompt {
        let elapsed: TimeInterval
        let minimumToCount: TimeInterval
        var canCount: Bool { elapsed >= minimumToCount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(viewModel.state.phase.title(profileLabel: viewModel.profileLabel))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                countdownText
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                cycleDots
                controls
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(viewModel.accentColor.color)
        .alert("Restart Pomodoro?", isPresented: $showingRestartConfirmation) {
            Button("Restart", role: .destructive) { viewModel.restart() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "End Focus early?",
            isPresented: Binding(
                get: { focusEndPrompt != nil },
                set: { if !$0 { focusEndPrompt = nil } }
            ),
            titleVisibility: .visible,
            presenting: focusEndPrompt
        ) { prompt in
            if prompt.canCount {
                Button("Finish & Count It") { viewModel.finishEarly() }
            }
            Button("Skip Without Counting", role: .destructive) { viewModel.skip() }
            Button("Keep Going", role: .cancel) {}
        } message: { prompt in
            if prompt.canCount {
                Text("Counts it in Stats and starts your break.")
            } else {
                Text("Sessions count once you're halfway.")
            }
        }
    }

    @ViewBuilder
    private var countdownText: some View {
        if viewModel.state.sessionActive {
            if viewModel.state.pausedAt != nil {
                Text(viewModel.state.formattedRemainingWhilePaused)
                    .accessibilityLabel(SpokenDuration.pausedLabel(endDate: viewModel.state.endDate, pausedAt: viewModel.state.pausedAt))
            } else {
                Text(timerInterval: viewModel.state.startDate...viewModel.state.endDate, countsDown: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        } else {
            Text("Ready")
        }
    }

    private var cycleDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.profile.sessionsBeforeLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.state.completedWorkCycles ? viewModel.accentColor.color : Color.clear)
                    .overlay(Circle().strokeBorder(viewModel.accentColor.color, lineWidth: 1.5))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle progress")
        .accessibilityValue("\(min(viewModel.state.completedWorkCycles, viewModel.profile.sessionsBeforeLongBreak)) of \(viewModel.profile.sessionsBeforeLongBreak) Focus sessions done")
    }

    @ViewBuilder
    private var controls: some View {
        if !viewModel.state.sessionActive {
            // Accent-filled, with a black or white label picked for contrast
            // (a white label on the default white accent was invisible).
            Button {
                viewModel.start()
            } label: {
                Text("Start")
                    .foregroundStyle(viewModel.accentColor.contrastingTextColor)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.accentColor.color)
        } else {
            HStack(spacing: 8) {
                if viewModel.state.pausedAt == nil {
                    Button { viewModel.pause() } label: {
                        Image(systemName: "pause.fill")
                    }
                    .accessibilityLabel("Pause")
                } else {
                    Button { viewModel.resume() } label: {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Resume")
                }
                Button {
                    if viewModel.state.phase == .work, let elapsed = viewModel.focusElapsed() {
                        focusEndPrompt = FocusEndPrompt(elapsed: elapsed, minimumToCount: viewModel.minimumFocusToCount)
                    } else {
                        viewModel.skip()
                    }
                } label: {
                    Image(systemName: "forward.fill")
                }
                .accessibilityLabel("Skip")
                Button { showingRestartConfirmation = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("Restart session")
            }
            .buttonStyle(.bordered)
            .tint(viewModel.accentColor.color)
        }
    }
}
