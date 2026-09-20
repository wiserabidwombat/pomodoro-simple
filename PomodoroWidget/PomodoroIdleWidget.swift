// PomodoroWidget/PomodoroIdleWidget.swift
import WidgetKit
import SwiftUI

struct PomodoroIdleEntry: TimelineEntry {
    let date: Date
    let state: PomodoroState
    let accentColor: AccentColorOption
}

struct PomodoroIdleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PomodoroIdleEntry {
        PomodoroIdleEntry(date: Date(), state: .idle, accentColor: .white)
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
            completion(PomodoroIdleEntry(date: now, state: example, accentColor: .white))
            return
        }
        let store = PomodoroStateStore()
        completion(PomodoroIdleEntry(date: Date(), state: store.loadState(), accentColor: store.loadAccentColor()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroIdleEntry>) -> Void) {
        let store = PomodoroStateStore()
        let state = store.loadState()
        let entry = PomodoroIdleEntry(date: Date(), state: state, accentColor: store.loadAccentColor())
        // The real update path is the explicit WidgetCenter.reloadTimelines
        // calls in TimerViewModel and the Live Activity intents, fired on
        // every start/pause/resume/skip/restart. This reload-at-endDate (or
        // in an hour if idle) is just a fallback in case one of those is
        // ever missed. Clamped to at least 30s out — if the phone went
        // unreloaded long enough for endDate to already be in the past,
        // asking WidgetKit to reload "after" a past date can trigger rapid
        // repeated reload attempts instead of one clean one.
        let fallback = state.sessionActive ? state.endDate : Date().addingTimeInterval(3600)
        let nextReload = max(fallback, Date().addingTimeInterval(30))
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }
}

struct PomodoroIdleWidgetView: View {
    let entry: PomodoroIdleEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularContent
            case .accessoryRectangular:
                rectangularContent
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
            VStack(spacing: 1) {
                Image(systemName: "timer")
                    .font(.caption2)
                countdownText
                    .font(.caption2)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        } else {
            Image(systemName: "timer")
                .font(.title2)
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
            Text(entry.state.sessionActive ? entry.state.phase.displayName : "Pomodoro")
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
            Text(entry.state.sessionActive ? entry.state.phase.displayName : "Pomodoro")
                .font(.caption)
            if entry.state.sessionActive {
                countdownText
                    .font(.title3.bold())
                    .monospacedDigit()
                // Plain AppIntents (WidgetPause.../WidgetResume.../WidgetSkip...),
                // not the LiveActivityIntent-conforming Pause/Resume/Skip used
                // by the Live Activity — those wake the full app process to
                // run, which is necessary for them to find the Live Activity
                // but adds several seconds of latency that's pointless for a
                // plain widget tap with nothing to look up.
                HStack(spacing: 20) {
                    if entry.state.pausedAt == nil {
                        Button(intent: WidgetPausePomodoroIntent()) {
                            Image(systemName: "pause.fill")
                        }
                    } else {
                        Button(intent: WidgetResumePomodoroIntent()) {
                            Image(systemName: "play.fill")
                        }
                    }
                    Button(intent: WidgetSkipPomodoroIntent()) {
                        Image(systemName: "forward.fill")
                    }
                }
            } else {
                Image(systemName: "timer")
                    .font(.title2)
            }
        }
    }

    @ViewBuilder
    private var countdownText: some View {
        if entry.state.pausedAt != nil {
            Text(entry.state.formattedRemainingWhilePaused)
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
                .widgetURL(URL(string: "pomodoro://open"))
        }
        .configurationDisplayName("Simple: StandBy Timer")
        .description("Shows your current Pomodoro phase and countdown.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall])
    }
}
