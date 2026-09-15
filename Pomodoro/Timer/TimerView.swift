// Pomodoro/Timer/TimerView.swift
import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(viewModel.state.phase.displayName)
                    .font(.title2.bold())
                if viewModel.state.sessionActive {
                    Text(
                        timerInterval: viewModel.state.startDate...viewModel.state.endDate,
                        pauseTime: viewModel.state.pausedAt,
                        countsDown: true
                    )
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                } else {
                    Text("Ready")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                }
                controls
            }
            .foregroundStyle(viewModel.accentColor.color)
            .padding()
        }
        .onAppear {
            NotificationScheduler().requestAuthorization { _ in }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshFromSharedState()
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if !viewModel.state.sessionActive {
            Button("Start") { viewModel.start() }
        } else {
            HStack(spacing: 20) {
                if viewModel.state.pausedAt == nil {
                    Button("Pause") { viewModel.pause() }
                } else {
                    Button("Resume") { viewModel.resume() }
                }
                Button("Skip") { viewModel.skip() }
            }
        }
    }
}
