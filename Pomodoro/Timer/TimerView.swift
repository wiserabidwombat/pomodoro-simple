// Pomodoro/Timer/TimerView.swift
import StoreKit
import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var showingRestartConfirmation = false
    @State private var showingHelp = false
    @State private var showingNotificationPrimer = false
    @AppStorage("hasSeenPomodoroHelp") private var hasSeenHelp = false
    @AppStorage("hasSeenNotificationPrimer") private var hasSeenNotificationPrimer = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(viewModel.state.phase.displayName)
                    .font(.title2.bold())
                if viewModel.state.sessionActive {
                    // `Text(timerInterval:pauseTime:)`'s own pause handling has
                    // proven unreliable on this SDK (the countdown keeps
                    // ticking past the pause point). Instead: a plain static
                    // string while paused, and the live self-updating Text
                    // (with no pauseTime at all) only while actually running.
                    if viewModel.state.pausedAt != nil {
                        Text(viewModel.state.formattedRemainingWhilePaused)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    } else {
                        // Text(timerInterval:) reserves a wider bounding box
                        // than it visually needs (to avoid jitter as the
                        // digit count changes) and renders left-aligned
                        // within it by default — multilineTextAlignment
                        // forces the glyphs themselves to center within it.
                        Text(
                            timerInterval: viewModel.state.startDate...viewModel.state.endDate,
                            countsDown: true
                        )
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    Text("Ready")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                }
                cycleProgress
                controls
            }
            .foregroundStyle(viewModel.accentColor.color)
            .padding()

            VStack {
                HStack {
                    Button {
                        showingHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                    }
                    .foregroundStyle(viewModel.accentColor.color.opacity(0.7))
                    .padding()

                    Spacer()

                    if viewModel.state.sessionActive {
                        Button {
                            showingRestartConfirmation = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                        }
                        .foregroundStyle(viewModel.accentColor.color.opacity(0.7))
                        .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            if !hasSeenNotificationPrimer {
                showingNotificationPrimer = true
            } else if !hasSeenHelp {
                hasSeenHelp = true
                showingHelp = true
            }
        }
        .onChange(of: viewModel.pendingReviewRequest) { _, isPending in
            if isPending {
                requestReview()
                viewModel.pendingReviewRequest = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.refreshFromSharedState()
            }
        }
        .alert(
            "Restart Pomodoro?",
            isPresented: $showingRestartConfirmation
        ) {
            Button("Restart", role: .destructive) { viewModel.restart() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This stops the current session and resets back to the start of a fresh Work phase.")
        }
        .sheet(isPresented: $showingHelp) {
            HelpView(accentColor: viewModel.accentColor, durations: viewModel.durations)
        }
        .sheet(isPresented: $showingNotificationPrimer, onDismiss: {
            if !hasSeenHelp {
                hasSeenHelp = true
                showingHelp = true
            }
        }) {
            NotificationPrimerView(accentColor: viewModel.accentColor) { enableNotifications in
                hasSeenNotificationPrimer = true
                showingNotificationPrimer = false
                if enableNotifications {
                    NotificationScheduler().requestAuthorization { _ in }
                }
            }
            .interactiveDismissDisabled()
        }
    }

    /// 4 dots for the classic Pomodoro cycle: filled for each completed
    /// Focus session since the last Long Break, resetting to empty once
    /// that 4th one lands. Uses `completedWorkCycles` directly, no new
    /// state needed.
    private var cycleProgress: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.state.completedWorkCycles ? viewModel.accentColor.color : Color.clear)
                    .overlay(Circle().strokeBorder(viewModel.accentColor.color, lineWidth: 1.5))
                    .frame(width: 12, height: 12)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if !viewModel.state.sessionActive {
            Button("Start") { viewModel.start() }
        } else {
            HStack(spacing: 20) {
                // Fixed width so the Skip button doesn't shift when this
                // label's text changes length between "Pause" and "Resume".
                Group {
                    if viewModel.state.pausedAt == nil {
                        Button("Pause") { viewModel.pause() }
                    } else {
                        Button("Resume") { viewModel.resume() }
                    }
                }
                .frame(width: 90)
                Button("Skip") { viewModel.skip() }
            }
        }
    }
}
