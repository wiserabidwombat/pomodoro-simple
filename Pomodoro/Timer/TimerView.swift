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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// iPad only: just the ring, countdown, and time of day (see DeskModeView).
    @State private var deskMode = false
    /// The iPad side panel's Today and This week data, refreshed when
    /// history changes rather than on every tick.
    @State private var recentActivity = TimerViewModel.RecentActivity()
    /// iPad's Picture in Picture countdown (see FloatingTimerController).
    @StateObject private var floatingTimer = FloatingTimerController()

    var body: some View {
        ZStack {
            ThemedBackground(theme: viewModel.activeTheme, showsParticles: true, isAnimating: isVisible)
            if usesWideLayout && deskMode {
                DeskModeView(
                    state: viewModel.state,
                    phaseTitle: phaseTitle,
                    phaseLength: phaseLength,
                    accent: viewModel.displayAccent.color
                ) {
                    deskMode = false
                }
            } else if usesWideLayout {
                wideContent
            } else {
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
                .foregroundStyle(viewModel.displayAccent.color)
                .padding()
            }

            if !(usesWideLayout && deskMode) {
                VStack {
                    HStack {
                        Button {
                            showingHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.title3)
                        }
                        .accessibilityLabel("How it works")
                        .foregroundStyle(viewModel.displayAccent.color.opacity(0.7))
                        .padding()

                        Spacer()

                        if usesWideLayout {
                            Button {
                                deskMode = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title3)
                            }
                            .accessibilityLabel("Desk Mode")
                            .accessibilityHint("Shows just the timer and the time of day, as large as possible.")
                            .keyboardShortcut("d", modifiers: .command)
                            .foregroundStyle(viewModel.displayAccent.color.opacity(0.7))
                            .padding(.vertical)
                            .padding(.leading)

                            if FloatingTimerController.isSupported {
                                Button {
                                    floatingTimer.toggle()
                                } label: {
                                    Image(systemName: floatingTimer.isActive ? "pip.exit" : "pip.enter")
                                        .font(.title3)
                                }
                                .accessibilityLabel(floatingTimer.isActive ? "Close floating timer" : "Floating timer")
                                .accessibilityHint("Shows the countdown in a small window that stays on screen over other apps.")
                                .keyboardShortcut("p", modifiers: [.command, .shift])
                                .foregroundStyle(viewModel.displayAccent.color.opacity(0.7))
                                .padding(.vertical)
                                .padding(.leading)
                            }
                        }

                        if viewModel.state.sessionActive {
                            Button {
                                showingRestartConfirmation = true
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title3)
                            }
                            .accessibilityLabel("Restart session")
                            // External-keyboard shortcuts (mostly for iPad):
                            // ⌘R restart, Space start/pause/resume, S skip.
                            .keyboardShortcut("r", modifiers: .command)
                            .foregroundStyle(viewModel.displayAccent.color.opacity(0.7))
                            .padding()
                        }
                    }
                    Spacer()
                }
            }

            if let theme = viewModel.activeTheme {
                CelebrationBurstView(theme: theme, trigger: viewModel.celebrationCount)
            }
        }
        // Picture in Picture needs its video layer in the window; tiny, black,
        // and behind everything, so it's never seen.
        .background(alignment: .bottomLeading) {
            if usesWideLayout && FloatingTimerController.isSupported {
                FloatingTimerLayerHost(displayLayer: floatingTimer.displayLayer)
                    .frame(width: 2, height: 2)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            isVisible = true
            if floatingTimer.viewModel == nil {
                floatingTimer.viewModel = viewModel
            }
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
        .onChange(of: deskMode) { _, _ in updateIdleTimer() }
        // Desk Mode is iPad-only; leaving the wide layout (e.g. into narrow
        // Split View) leaves Desk Mode too.
        .onChange(of: usesWideLayout) { _, wide in
            if !wide { deskMode = false }
        }
        .task(id: "\(viewModel.historyRevision)-\(usesWideLayout)") {
            if usesWideLayout {
                recentActivity = viewModel.recentActivity()
            }
        }
        .toolbar(deskMode ? .hidden : .automatic, for: .tabBar)
        .statusBarHidden(deskMode)
        .persistentSystemOverlays(deskMode ? .hidden : .automatic)
        .animation(.easeInOut(duration: 0.3), value: deskMode)
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
            HelpView(accentColor: viewModel.displayAccent, profile: viewModel.activeProfile)
        }
        .sheet(isPresented: $showingNotificationPrimer, onDismiss: {
            if !hasSeenHelp {
                hasSeenHelp = true
                showingHelp = true
            }
        }) {
            NotificationPrimerView(accentColor: viewModel.displayAccent) { enableNotifications in
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
        // Desk Mode always keeps the screen on: that's its whole point.
        UIApplication.shared.isIdleTimerDisabled = isVisible
            && (deskMode || (viewModel.keepScreenAwake && viewModel.state.sessionActive))
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
                        .overlay(Capsule().strokeBorder(viewModel.displayAccent.color.opacity(0.6), lineWidth: 1))
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
                    .fill(index < viewModel.state.completedWorkCycles ? viewModel.displayAccent.color : Color.clear)
                    .overlay(Circle().strokeBorder(viewModel.displayAccent.color, lineWidth: 1.5))
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
                .keyboardShortcut(.space, modifiers: [])
        } else {
            HStack(spacing: 20) {
                // Minimum width so the Skip button doesn't shift when this
                // label's text changes length between "Pause" and "Resume" —
                // a minimum rather than a fixed 90pt, so larger Dynamic Type
                // sizes can grow the button instead of truncating "Resume".
                Group {
                    if viewModel.state.pausedAt == nil {
                        Button("Pause") { viewModel.pause() }
                            .keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button("Resume") { viewModel.resume() }
                            .keyboardShortcut(.space, modifiers: [])
                    }
                }
                .frame(minWidth: 90)
                Button("Skip") { skipTapped() }
                .keyboardShortcut("s", modifiers: [])
                .accessibilityHint(viewModel.state.phase == .work
                    ? "Lets you finish this Focus session early and count it, or skip it without counting."
                    : "Ends this break now and starts the next Focus session.")
            }
        }
    }

    // MARK: - iPad layout

    /// Full-screen and wide Split View iPad. Narrow Split View, Slide Over,
    /// and every iPhone get the compact layout above.
    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }

    private var phaseLength: TimeInterval {
        viewModel.activeProfile.durations.duration(for: viewModel.state.phase)
    }

    /// "Deep Work · Focus" with more than one profile, else just "Focus".
    private var phaseTitle: String {
        viewModel.state.phase.title(profileLabel: viewModel.profiles.count > 1 ? viewModel.activeProfile.name : nil)
    }

    /// Landscape: the timer on the left, a column of cards on the right.
    /// Portrait: the timer on top, the cards in a 2×2 grid below. The ring
    /// scales with the screen instead of staying phone-sized.
    private var wideContent: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if size.width > size.height {
                HStack(alignment: .center, spacing: 40) {
                    wideTimerColumn(diameter: min(size.width * 0.46, size.height * 0.62))
                        .frame(maxWidth: .infinity)
                    sidePanel(columns: 1)
                        .frame(width: min(340, size.width * 0.3))
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 32) {
                    wideTimerColumn(diameter: min(size.width * 0.6, size.height * 0.38))
                    sidePanel(columns: 2)
                        .frame(maxWidth: 640)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Clears the help / Desk Mode / restart buttons along the top.
        .padding(.top, 56)
        .padding(.bottom, 16)
        .foregroundStyle(viewModel.displayAccent.color)
    }

    private func wideTimerColumn(diameter: CGFloat) -> some View {
        VStack(spacing: 28) {
            TimerRing(
                state: viewModel.state,
                phaseLength: phaseLength,
                color: viewModel.displayAccent.color,
                lineWidth: max(8, diameter * 0.03)
            ) {
                VStack(spacing: diameter * 0.03) {
                    Text(viewModel.state.sessionActive ? viewModel.state.phase.displayName : "Ready")
                        .font(.system(size: diameter * 0.065, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Group {
                        if viewModel.state.sessionActive {
                            CountdownText(state: viewModel.state)
                        } else {
                            // The Focus length Start will run, rather than
                            // repeating "Ready".
                            Text("\(viewModel.activeProfile.durations.workMinutes):00")
                                .accessibilityLabel("\(viewModel.activeProfile.durations.workMinutes) minute Focus session")
                        }
                    }
                    .font(.system(size: diameter * 0.2, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    if viewModel.profiles.count > 1 {
                        Text(viewModel.activeProfile.name)
                            .font(.system(size: diameter * 0.045))
                            .lineLimit(1)
                            .opacity(0.6)
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            cycleProgress
            wideControls
        }
    }

    /// Big, proper buttons instead of text links: the primary action filled
    /// in the accent color, Skip outlined. Same keyboard shortcuts.
    @ViewBuilder
    private var wideControls: some View {
        let accent = viewModel.displayAccent
        HStack(spacing: 16) {
            if !viewModel.state.sessionActive {
                Button { viewModel.start() } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 160)
                        .foregroundStyle(accent.contrastingTextColor)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Group {
                    if viewModel.state.pausedAt == nil {
                        Button { viewModel.pause() } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(minWidth: 140)
                                .foregroundStyle(accent.contrastingTextColor)
                        }
                    } else {
                        Button { viewModel.resume() } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(minWidth: 140)
                                .foregroundStyle(accent.contrastingTextColor)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [])
                Button { skipTapped() } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(minWidth: 110)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("s", modifiers: [])
                .accessibilityHint(viewModel.state.phase == .work
                    ? "Lets you finish this Focus session early and count it, or skip it without counting."
                    : "Ends this break now and starts the next Focus session.")
            }
        }
        .controlSize(.large)
        .font(.title3.weight(.semibold))
        .tint(accent.color)
    }

    private func sidePanel(columns: Int) -> some View {
        let accent = viewModel.displayAccent.color
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: columns),
            spacing: 16
        ) {
            TodayCard(
                todayCount: viewModel.todayCount,
                dailyGoal: viewModel.dailyGoal,
                focusSeconds: recentActivity.todayFocusSeconds,
                accent: accent
            )
            UpNextCard(state: viewModel.state, profile: viewModel.activeProfile, accent: accent)
            WeekCard(days: recentActivity.lastSevenDays, dailyGoal: viewModel.dailyGoal, accent: accent)
            PanelCard(title: "Profile", systemImage: "slider.horizontal.3", accent: accent) {
                profileCardContent
            }
        }
    }

    /// The profile switcher, moved off the timer into its own card. Like
    /// the iPhone's, it only switches while no session is running.
    @ViewBuilder
    private var profileCardContent: some View {
        if viewModel.profiles.count > 1 && !viewModel.state.sessionActive {
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
                HStack(spacing: 6) {
                    Text(viewModel.activeProfile.name)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                }
            }
            .accessibilityLabel("Timer profile")
            .accessibilityValue(viewModel.activeProfile.name)
            .accessibilityHint("Choose which profile the next session uses.")
        } else {
            Text(viewModel.activeProfile.name)
                .font(.headline)
                .lineLimit(1)
        }
        Text(viewModel.activeProfile.summary)
            .font(.caption)
            .opacity(0.6)
            .accessibilityLabel(viewModel.activeProfile.spokenSummary)
        if viewModel.profiles.count > 1 && viewModel.state.sessionActive {
            Text("You can switch profiles when no session is running.")
                .font(.caption2)
                .opacity(0.5)
        }
    }

    /// During Focus, ask first: Skip used to silently throw away a nearly
    /// finished session. Breaks skip at once.
    private func skipTapped() {
        if viewModel.state.phase == .work, let elapsed = viewModel.focusElapsed() {
            focusEndPrompt = FocusEndPrompt(elapsed: elapsed, minimumToCount: viewModel.minimumFocusToCount)
        } else {
            viewModel.skip()
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
                    .tint(viewModel.displayAccent.color)
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
