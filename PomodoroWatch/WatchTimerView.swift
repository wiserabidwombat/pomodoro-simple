// PomodoroWatch/WatchTimerView.swift
import SwiftUI

struct WatchTimerView: View {
    @ObservedObject var viewModel: WatchTimerViewModel
    @State private var showingRestartConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(viewModel.state.phase.displayName)
                    .font(.headline)
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
    }

    @ViewBuilder
    private var countdownText: some View {
        if viewModel.state.sessionActive {
            if viewModel.state.pausedAt != nil {
                Text(viewModel.state.formattedRemainingWhilePaused)
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
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.state.completedWorkCycles ? viewModel.accentColor.color : Color.clear)
                    .overlay(Circle().strokeBorder(viewModel.accentColor.color, lineWidth: 1.5))
                    .frame(width: 8, height: 8)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if !viewModel.state.sessionActive {
            Button("Start") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.accentColor.color)
                .foregroundStyle(.black)
        } else {
            HStack(spacing: 10) {
                if viewModel.state.pausedAt == nil {
                    Button { viewModel.pause() } label: {
                        Image(systemName: "pause.fill")
                    }
                } else {
                    Button { viewModel.resume() } label: {
                        Image(systemName: "play.fill")
                    }
                }
                Button { viewModel.skip() } label: {
                    Image(systemName: "forward.fill")
                }
                Button { showingRestartConfirmation = true } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .buttonStyle(.bordered)
            .tint(viewModel.accentColor.color)
        }
    }
}
