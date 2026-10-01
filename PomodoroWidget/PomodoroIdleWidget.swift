// PomodoroWidget/PomodoroIdleWidget.swift
import WidgetKit
import SwiftUI

struct PomodoroIdleEntry: TimelineEntry {
    let date: Date
    let state: PomodoroState
    let accentColor: AccentColorOption
    let todayCount: Int
    /// The active profile's name, or nil when there's only one profile.
    var profileLabel: String? = nil
    var sessionsPerCycle: Int = 4
    /// Full length of the current phase, for the Lock Screen progress ring.
    /// (endDate − startDate isn't it: pausing pushes endDate back.)
    var phaseLength: TimeInterval = 0
    /// Settings → Daily Goal (0 = off); the medium widget shows "3/6".
    var dailyGoal: Int = 0
}

struct PomodoroIdleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroIdleEntry {
        PomodoroIdleEntry(date: Date(), state: .idle, accentColor: .white, todayCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroIdleEntry) -> Void) {
        // The widget gallery (context.isPreview) should show a representative
        // example, not the user's real current state — Apple's own WidgetKit
        // guidance calls this out explicitly, and it also means someone
        // browsing the gallery with no session running sees what an active
        // session looks like rather than a bare "Ready".
        if context.isPreview {
            let now = Date()
            let example = PomodoroState(
                phase: .work,
                startDate: now,
                endDate: now.addingTimeInterval(12 * 60 + 34),
                pausedAt: nil,
                completedWorkCycles: 1,
                sessionActive: true
            )
            completion(PomodoroIdleEntry(date: now, state: example, accentColor: .white, todayCount: 3, sessionsPerCycle: 4, phaseLength: 25 * 60))
            return
        }
        let store = PomodoroStateStore()
        let state = store.loadState()
        let profile = store.loadActiveProfile()
        completion(PomodoroIdleEntry(
            date: Date(),
            state: state,
            accentColor: store.loadEffectiveAccentColor(),
            todayCount: store.loadCachedTodayCount(),
            profileLabel: store.loadActiveProfileLabel(),
            sessionsPerCycle: profile.sessionsBeforeLongBreak,
            phaseLength: profile.durations.duration(for: state.phase),
            dailyGoal: store.loadDailyGoal()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroIdleEntry>) -> Void) {
        let store = PomodoroStateStore()
        let state = store.loadState()
        let accentColor = store.loadEffectiveAccentColor()
        let todayCount = store.loadCachedTodayCount()
        let profileLabel = store.loadActiveProfileLabel()
        let activeProfile = store.loadActiveProfile()
        let sessionsPerCycle = activeProfile.sessionsBeforeLongBreak
        let phaseLength = activeProfile.durations.duration(for: state.phase)
        let dailyGoal = store.loadDailyGoal()
        let now = Date()
        func entry(at date: Date) -> PomodoroIdleEntry {
            PomodoroIdleEntry(
                date: date,
                state: state,
                accentColor: accentColor,
                todayCount: todayCount,
                profileLabel: profileLabel,
                sessionsPerCycle: sessionsPerCycle,
                phaseLength: phaseLength,
                dailyGoal: dailyGoal
            )
        }

        var entries = [entry(at: now)]
        let nextReload: Date
        if state.sessionActive, state.pausedAt == nil, state.endDate > now {
            // A second entry dated at the phase's end flips the widget to
            // its "Time's up" + Continue state exactly on time, with no
            // reload needed (see PomodoroIdleWidgetView.isExpired).
            entries.append(entry(at: state.endDate))
            nextReload = state.endDate.addingTimeInterval(3600)
        } else {
            nextReload = now.addingTimeInterval(3600)
        }
        // The real update path is the explicit WidgetCenter.reloadTimelines
        // calls in TimerViewModel and the intents, fired on every change.
        // This is only a fallback in case one is ever missed. It used to be
        // "at endDate, but at least 30s out" — which, once a phase had
        // expired, meant asking WidgetKit to reload every 30 seconds for as
        // long as it sat expired, spending the widget's daily reload budget.
        completion(Timeline(entries: entries, policy: .after(nextReload)))
    }
}

struct PomodoroIdleWidgetView: View {
    let entry: PomodoroIdleEntry
    @Environment(\.widgetFamily) private var family

    /// The phase ran out and nothing has advanced it yet — nothing runs in
    /// the background when that happens. Shown as "Time's up" with a
    /// Continue button (like the Live Activity) rather than a frozen 00:00
    /// with Pause/Skip, where Skip would catch up *and* skip, advancing two
    /// phases in one tap.
    /// "Deep Work · Focus" (or just "Focus") during a session; with no
    /// session, the profile that Start would use, or "Pomodoro".
    private var title: String {
        if entry.state.sessionActive {
            return entry.state.phase.title(profileLabel: entry.profileLabel)
        }
        return entry.profileLabel ?? "Pomodoro"
    }

    private var isExpired: Bool {
        entry.state.sessionActive && entry.state.pausedAt == nil && entry.date >= entry.state.endDate
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularContent
            case .accessoryRectangular:
                rectangularContent
            case .systemMedium:
                mediumContent
            default:
                homeScreenContent
            }
        }
        .foregroundStyle(entry.accentColor.color)
        // iOS 17+ widgets must declare their background via containerBackground
        // rather than an opaque view in the body — the system manages
        // rendering (including StandBy's full-color mode) around it.
        .containerBackground(.black, for: .widget)
    }

    @ViewBuilder
    private var circularContent: some View {
        if entry.state.sessionActive {
            // A ring that drains as the phase counts down. While running it's
            // ProgressView(timerInterval:), which iOS animates on its own —
            // no timeline entries or reloads needed, same as the countdown
            // text. Paused, it's a static ring frozen at the paused point;
            // expired, an empty ring with a checkmark.
            ZStack {
                AccessoryWidgetBackground()
                progressRing
                ringCenter
                    .padding(.horizontal, 6)
            }
            .accessibilityElement(children: .combine)
        } else {
            Image(systemName: "timer")
                .font(.title2)
                .accessibilityLabel("Pomodoro timer, not running")
        }
    }

    /// The phase's full span, ending at endDate — built from the phase
    /// length rather than startDate, because pausing moves endDate later
    /// without moving startDate, which would make the ring show less time
    /// left than the countdown does.
    private var ringRange: ClosedRange<Date> {
        let end = entry.state.endDate
        let length = entry.phaseLength > 0 ? entry.phaseLength : end.timeIntervalSince(entry.state.startDate)
        return end.addingTimeInterval(-max(length, 1))...end
    }

    @ViewBuilder
    private var progressRing: some View {
        if isExpired {
            ProgressView(value: 0.0)
                .progressViewStyle(.circular)
        } else if let pausedAt = entry.state.pausedAt {
            let total = ringRange.upperBound.timeIntervalSince(ringRange.lowerBound)
            let remaining = max(0, entry.state.endDate.timeIntervalSince(pausedAt))
            ProgressView(value: min(remaining, total), total: total)
                .progressViewStyle(.circular)
        } else {
            ProgressView(timerInterval: ringRange, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
        }
    }

    @ViewBuilder
    private var ringCenter: some View {
        if isExpired {
            Image(systemName: "checkmark")
                .font(.body.bold())
                .accessibilityLabel("\(entry.state.phase.displayName) finished")
        } else {
            VStack(spacing: 0) {
                if entry.state.pausedAt != nil {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 8))
                        .accessibilityHidden(true)
                }
                countdownText
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    // Text-only, no buttons: StandBy/Lock Screen's accessoryRectangular is
    // ~160x50pt, and adding a button here caused the widget to fail to
    // render at all on-device (falling back to a bare placeholder), even
    // though it looked fine in the widget gallery's static preview. StandBy
    // also already has the Live Activity as its primary interactive surface
    // while a session is running, so this isn't a real loss of capability.
    @ViewBuilder
    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.caption.bold())
            if entry.state.sessionActive {
                countdownText
                    .font(.title3)
                    .monospacedDigit()
            } else {
                Text("Tap to start")
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var homeScreenContent: some View {
        VStack(spacing: 4) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.caption)
            if entry.state.sessionActive {
                countdownText
                    .font(.title3.bold())
                    .monospacedDigit()
                controls
            } else {
                startButton
            }
        }
    }

    // Wider canvas than homeScreenContent (systemSmall), so this also
    // surfaces cycle progress and today's count — the two things that don't
    // fit anywhere else on the Home Screen without opening the app.
    private var mediumContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.headline)
                if entry.state.sessionActive {
                    countdownText
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    controls
                } else {
                    startButton
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 12) {
                cycleDots
                VStack(alignment: .trailing, spacing: 0) {
                    Text(entry.dailyGoal > 0 ? "\(entry.todayCount)/\(entry.dailyGoal)" : "\(entry.todayCount)")
                        .font(.title2.bold())
                    Text(entry.dailyGoal > 0 && entry.todayCount >= entry.dailyGoal ? "Goal met" : "Today")
                        .font(.caption2)
                        .opacity(0.7)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today")
                .accessibilityValue(entry.dailyGoal > 0
                    ? "\(entry.todayCount) of \(entry.dailyGoal) Focus sessions"
                    : "\(entry.todayCount) Focus sessions")
            }
        }
    }

    private var cycleDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<entry.sessionsPerCycle, id: \.self) { index in
                Circle()
                    .fill(index < entry.state.completedWorkCycles ? entry.accentColor.color : Color.clear)
                    .overlay(Circle().strokeBorder(entry.accentColor.color, lineWidth: 1.5))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle progress")
        .accessibilityValue("\(min(entry.state.completedWorkCycles, entry.sessionsPerCycle)) of \(entry.sessionsPerCycle) Focus sessions done")
    }

    /// Starts a session with the active profile right from the Home Screen
    /// (the title above it names the profile when there's more than one).
    /// Same LiveActivityIntent as Siri/Shortcuts' "Start", so the app wakes
    /// in the background and the Live Activity appears as usual. Only on
    /// the Home Screen sizes: Lock Screen accessory widgets are too small
    /// for buttons (see rectangularContent).
    private var startButton: some View {
        Button(intent: StartPomodoroIntent()) {
            Label("Start", systemImage: "play.fill")
                .foregroundStyle(entry.accentColor.contrastingTextColor)
        }
        .buttonStyle(.borderedProminent)
        .tint(entry.accentColor.color)
        .accessibilityHint("Starts a Focus session.")
    }

    /// Same LiveActivityIntent-conforming intents the Live Activity's own
    /// buttons use (Shared/PomodoroLiveActivityIntents.swift) — required so
    /// the app process actually wakes and can find the running Activity to
    /// push the update to; a plain AppIntent here can't do that.
    @ViewBuilder
    private var controls: some View {
        if isExpired {
            Button(intent: AdvancePomodoroIntent()) {
                Label("Continue", systemImage: "arrow.right")
                    .foregroundStyle(entry.accentColor.contrastingTextColor)
            }
            .buttonStyle(.borderedProminent)
            .tint(entry.accentColor.color)
        } else {
            HStack(spacing: 20) {
                if entry.state.pausedAt == nil {
                    Button(intent: PausePomodoroIntent()) {
                        Image(systemName: "pause.fill")
                    }
                    .accessibilityLabel("Pause")
                } else {
                    Button(intent: ResumePomodoroIntent()) {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Resume")
                }
                Button(intent: SkipPomodoroIntent()) {
                    Image(systemName: "forward.fill")
                }
                .accessibilityLabel("Skip")
            }
        }
    }

    @ViewBuilder
    private var countdownText: some View {
        if isExpired {
            Text("Time's up")
        } else if entry.state.pausedAt != nil {
            Text(entry.state.formattedRemainingWhilePaused)
                .accessibilityLabel(SpokenDuration.pausedLabel(endDate: entry.state.endDate, pausedAt: entry.state.pausedAt))
        } else {
            // Text(timerInterval:) reserves a wider bounding box than it
            // visually needs and renders left-aligned within it by default —
            // multilineTextAlignment forces the glyphs to center (see
            // TimerView/PomodoroLiveActivityWidget for the same fix).
            Text(timerInterval: entry.state.startDate...entry.state.endDate, countsDown: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

struct PomodoroIdleWidget: Widget {
    let kind = "PomodoroIdleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroIdleProvider()) { entry in
            PomodoroIdleWidgetView(entry: entry)
                .widgetURL(PomodoroDeepLink.timerURL)
        }
        .configurationDisplayName("Simple: StandBy Timer")
        .description("Shows your current Pomodoro phase and countdown.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall, .systemMedium])
    }
}
