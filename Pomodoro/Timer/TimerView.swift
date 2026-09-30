// Pomodoro/Timer/TimerView.swift
import StoreKit
import SwiftUI
import UIKit

struct TimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @Environment(\.requestReview) private var requestReview
    @State private var showingRestartConfirmation = false
    /// Set when Skip is tapped during Focus; drives the "end Focus early?"
    /// choice between counting the session and throwing it away.
    @State private var focusEndPrompt: FocusEndPrompt?

    private struct FocusEndPrompt {
        let elapsed: TimeInterval
        let minimumToCount: TimeInterval
        var canCount: Bool { elapsed >= minimumToCount }
    }
    @State private var showingHelp = false
    @State private var showingNotificationPrimer = false
    @AppStorage("hasSeenPomodoroHelp") private var hasSeenHelp = false
    @AppStorage("hasSeenNotificationPrimer") private var hasSeenNotificationPrimer = false
    /// Whether this tab is the one on screen (a TabView keeps it alive
    /// while other tabs show, so appearance has to be tracked).
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(viewModel.state.phase.displayName)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                profilePicker
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
                            // "12:34" alone is read as a clock time.
                            .accessibilityLabel(SpokenDuration.pausedLabel(endDate: viewModel.state.endDate, pausedAt: viewModel.state.pausedAt))
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
                        // No accessibility override here on purpose: the
                        // live timer text already reads its current value to
                        // VoiceOver, while a label computed at render time
                        // would go stale (this view isn't redrawn every second).
                    }
                } else {
                    Text("Ready")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                }
                cycleProgress
                controls
                dailyGoalProgress
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
                    .accessibilityLabel("How it works")
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
                        .accessibilityLabel("Restart session")
                        .foregroundStyle(viewModel.accentColor.color.opacity(0.7))
                        .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            isVisible = true
            updateIdleTimer()
            if !hasSeenNotificationPrimer {
                showingNotificationPrimer = true
            } else if !hasSeenHelp {
                hasSeenHelp = true
                showingHelp = true
            }
        }
        .onDisappear {
            isVisible = false
            updateIdleTimer()
        }
        .onChange(of: viewModel.keepScreenAwake) { _, _ in updateIdleTimer() }
        .onChange(of: viewModel.state.sessionActive) { _, _ in updateIdleTimer() }
        .onChange(of: viewModel.pendingReviewRequest) { _, isPending in
            if isPending {
                requestReview()
                viewModel.pendingReviewRequest = false
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
                Text("You've focused for \(Self.minutesText(prompt.elapsed)). Finishing counts it in Stats and starts your break.")
            } else {
                Text("You're \(Self.minutesText(prompt.elapsed)) in. Finishing early counts once you're halfway (\(Self.minutesText(prompt.minimumToCount))) — until then, skipping won't count it.")
            }
        }
        .sheet(isPresented: $showingHelp) {
            HelpView(accentColor: viewModel.accentColor, profile: viewModel.activeProfile)
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

    /// "Keep Screen Awake" only holds the screen on while it's useful: the
    /// setting is on, a session is running (or paused), and this tab is
    /// showing. Switching tabs, stopping the session, or turning the setting
    /// off hands auto-lock straight back to the system. (iOS also ignores
    /// the flag while the app is in the background.)
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = isVisible
            && viewModel.keepScreenAwake
            && viewModel.state.sessionActive
    }

    /// Which timer profile this session uses. Tappable (a menu) only while
    /// idle; a running session shows the name without letting it change.
    /// Hidden entirely when there's only one profile.
    @ViewBuilder
    private var profilePicker: some View {
        if viewModel.profiles.count > 1 {
            if viewModel.state.sessionActive {
                Text(viewModel.activeProfile.name)
                    .font(.subheadline)
                    .opacity(0.7)
                    .accessibilityLabel("Timer profile: \(viewModel.activeProfile.name)")
            } else {
                VStack(spacing: 4) {
                    Menu {
                        Picker("Timer Profile", selection: Binding(
                            get: { viewModel.activeProfile.id },
                            set: { viewModel.selectProfile(id: $0) }
                        )) {
                            ForEach(viewModel.profiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            // Every profile name is laid out invisibly
                            // underneath the visible one, so the chip is
                            // always as wide as the longest name. Without
                            // this it resized — and re-centered — each time
                            // a different profile was picked. (Hidden views
                            // are also skipped by VoiceOver.)
                            ZStack {
                                ForEach(viewModel.profiles) { profile in
                                    Text(profile.name)
                                        .lineLimit(1)
                                        .hidden()
                                }
                                Text(viewModel.activeProfile.name)
                                    .lineLimit(1)
                            }
                            // Keeps a very long name from stretching the
                            // chip off-screen; it truncates instead.
                            .frame(maxWidth: 220)
                            Image(systemName: "chevron.down")
                                .font(.caption.bold())
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(viewModel.accentColor.color.opacity(0.6), lineWidth: 1))
                    }
                    .accessibilityLabel("Timer profile")
                    .accessibilityValue(viewModel.activeProfile.name)
                    .accessibilityHint("Choose which profile the next session uses.")
                    Text(viewModel.activeProfile.summary)
                        .font(.caption)
                        .opacity(0.6)
                        .accessibilityLabel(viewModel.activeProfile.spokenSummary)
                }
            }
        }
    }

    /// One dot per Focus session in the active profile's cycle: filled for
    /// each completed Focus session since the last Long Break, resetting to
    /// empty once the cycle's last one lands. Uses `completedWorkCycles`
    /// directly, no new state needed.
    private var cycleProgress: some View {
        HStack(spacing: 12) {
            ForEach(0..<viewModel.activeProfile.sessionsBeforeLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.state.completedWorkCycles ? viewModel.accentColor.color : Color.clear)
                    .overlay(Circle().strokeBorder(viewModel.accentColor.color, lineWidth: 1.5))
                    .frame(width: 12, height: 12)
            }
        }
        // One element instead of N unlabeled circles.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle progress")
        .accessibilityValue("\(min(viewModel.state.completedWorkCycles, viewModel.activeProfile.sessionsBeforeLongBreak)) of \(viewModel.activeProfile.sessionsBeforeLongBreak) Focus sessions done")
    }

    @ViewBuilder
    private var controls: some View {
        if !viewModel.state.sessionActive {
            Button("Start") { viewModel.start() }
        } else {
            HStack(spacing: 20) {
                // Minimum width so the Skip button doesn't shift when this
                // label's text changes length between "Pause" and "Resume" —
                // a minimum rather than a fixed 90pt, so larger Dynamic Type
                // sizes can grow the button instead of truncating "Resume".
                Group {
                    if viewModel.state.pausedAt == nil {
                        Button("Pause") { viewModel.pause() }
                    } else {
                        Button("Resume") { viewModel.resume() }
                    }
                }
                .frame(minWidth: 90)
                Button("Skip") {
                    // During Focus, ask first: Skip used to silently throw
                    // away a nearly finished session. Breaks skip at once.
                    if viewModel.state.phase == .work, let elapsed = viewModel.focusElapsed() {
                        focusEndPrompt = FocusEndPrompt(elapsed: elapsed, minimumToCount: viewModel.minimumFocusToCount)
                    } else {
                        viewModel.skip()
                    }
                }
                .accessibilityHint(viewModel.state.phase == .work
                    ? "Lets you finish this Focus session early and count it, or skip it without counting."
                    : "Ends this break now and starts the next Focus session.")
            }
        }
    }

    /// "22 minutes", "1 minute", "less than a minute".
    private static func minutesText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        switch minutes {
        case ..<1: return "less than a minute"
        case 1: return "1 minute"
        default: return "\(minutes) minutes"
        }
    }

    /// "3 of 6 today" with a thin bar, only when a daily goal is set
    /// (Settings → Daily Goal). Counts every profile's sessions.
    @ViewBuilder
    private var dailyGoalProgress: some View {
        if viewModel.dailyGoal > 0 {
            let done = viewModel.todayCount
            let goal = viewModel.dailyGoal
            VStack(spacing: 6) {
                ProgressView(value: Double(min(done, goal)), total: Double(goal))
                    .tint(viewModel.accentColor.color)
                    .frame(maxWidth: 180)
                Text(done >= goal ? "Daily goal reached · \(done) today" : "\(done) of \(goal) today")
                    .font(.caption)
                    .opacity(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily goal")
            .accessibilityValue(done >= goal
                ? "Reached, \(done) Focus sessions today"
                : "\(done) of \(goal) Focus sessions today")
        }
    }
}
